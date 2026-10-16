// SPDX-License-Identifier: GPL-2.0

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

static int test_reset(const char *val, const struct kernel_param *kp)
{
	pr_notice("rog-efi-poweroff: TEST ResetSystem(EfiResetShutdown) entering (runtime probe)\n");
	efi.reset_system(EFI_RESET_SHUTDOWN, EFI_SUCCESS, 0, NULL);
	pr_notice("rog-efi-poweroff: TEST ResetSystem returned without powering off\n");
	return 0;
}

static const struct kernel_param_ops test_reset_ops = {
	.set = test_reset,
};
module_param_cb(test_reset, &test_reset_ops, NULL, 0200);
MODULE_PARM_DESC(test_reset, "write 1: runtime ResetSystem probe (powers off or freezes, evidence via netconsole)");

static int rog_efi_power_off(struct sys_off_data *data)
{
	pr_notice("rog-efi-poweroff: ResetSystem(EfiResetShutdown) entering\n");
	efi.reset_system(EFI_RESET_SHUTDOWN, EFI_SUCCESS, 0, NULL);
	pr_notice("rog-efi-poweroff: ResetSystem returned without powering off\n");
	return NOTIFY_STOP;
}

static int __init rog_efi_poweroff_init(void)
{
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
