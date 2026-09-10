// SPDX-License-Identifier: GPL-2.0
/*
 * rog-efi-poweroff — DMI-scoped EFI ResetSystem power-off for the ASUS
 * ROG Strix GL553VD.
 *
 * Verified evidence (openspec change rog-shutdown-s5-diagnose-and-fix):
 * this firmware freezes during the hardware-level ACPI S5 transition.
 * The Sep 8 2026 netconsole trace captured the kernel dying after the
 * disk shutdown, and the Gate 2 trial (Sep 10 00:34) proved that a
 * direct, AML-bypassing PM1a_CNT SLP_EN write (0x1804, SLP_TYP=7,
 * 0x3C00) also freezes the box — the hang lives below the AML, in the
 * S5 entry itself. No kernel-side or AML-side change can fix that.
 *
 * The remaining firmware entry path is the UEFI runtime service
 * ResetSystem(EfiResetShutdown), which does not go through ACPI S5.
 * This module registers a SYS_OFF_MODE_POWER_OFF handler at
 * SYS_OFF_PRIO_FIRMWARE + 1 (225) — the exact mechanism mainline
 * uses in drivers/firmware/efi/reboot.c when efi_poweroff_required()
 * is true, so it runs INSTEAD of acpi_power_off (priority 224, the
 * final S5 entry) while the kernel's own, unconditional
 * acpi_power_off_prepare (POWER_OFF_PREPARE) still runs first: the
 * firmware keeps its _PTS/_GTS notification and every wake GPE is
 * disarmed, matching the lesson from the T14 Gen 5 RFC v3 where
 * skipping the prepare stage caused intermittent failures.
 *
 * If ResetSystem returns without powering off, the handler breaks the
 * chain (NOTIFY_STOP) so the known-hanging ACPI S5 entry can never
 * run afterwards; the breadcrumb line makes the outcome visible on
 * netconsole.
 */

#include <linux/dmi.h>
#include <linux/efi.h>
#include <linux/module.h>
#include <linux/reboot.h>

static const struct dmi_system_id rog_dmi_table[] __initconst = {
	{
		.matches = {
			DMI_MATCH(DMI_SYS_VENDOR, "ASUSTeK COMPUTER INC."),
			DMI_MATCH(DMI_PRODUCT_NAME, "GL553VD"),
		},
	},
	{}
};

static struct sys_off_handler *rog_sys_off;

static int rog_efi_power_off(struct sys_off_data *data)
{
	pr_notice("rog-efi-poweroff: ResetSystem(EfiResetShutdown) entering\n");
	efi.reset_system(EFI_RESET_SHUTDOWN, EFI_SUCCESS, 0, NULL);
	/*
	 * Control returning means the firmware did not power off. NOTIFY_STOP
	 * breaks the handler chain: falling through to acpi_power_off would
	 * walk into the known-freezing S5 entry with no way back.
	 */
	pr_notice("rog-efi-poweroff: ResetSystem returned without powering off\n");
	return NOTIFY_STOP;
}

static int __init rog_efi_poweroff_init(void)
{
	/* Inert on every machine except the affected firmware. */
	if (!dmi_check_system(rog_dmi_table))
		return -ENODEV;

	if (!efi_rt_services_supported(EFI_RT_SUPPORTED_RESET_SYSTEM))
		return -ENODEV;

	rog_sys_off = register_sys_off_handler(SYS_OFF_MODE_POWER_OFF,
					       SYS_OFF_PRIO_FIRMWARE + 1,
					       rog_efi_power_off, NULL);
	if (IS_ERR(rog_sys_off))
		return PTR_ERR(rog_sys_off);

	pr_notice("rog-efi-poweroff: EFI ResetSystem power-off handler registered (priority %d, replacing the freezing ACPI S5 entry)\n",
		  SYS_OFF_PRIO_FIRMWARE + 1);
	return 0;
}

static void __exit rog_efi_poweroff_exit(void)
{
	if (!IS_ERR_OR_NULL(rog_sys_off))
		unregister_sys_off_handler(rog_sys_off);
}

module_init(rog_efi_poweroff_init);
module_exit(rog_efi_poweroff_exit);
MODULE_LICENSE("GPL");
MODULE_AUTHOR("glats");
MODULE_DESCRIPTION("GL553VD: EFI ResetSystem power-off (ACPI S5 entry freezes this firmware)");
