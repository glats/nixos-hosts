# btop config for t14 (HM settings-based).
#
# Sets `programs.btop.settings` with `lib.mkForce` on every key.
# This drops omarchy-nix's defaults at eval time so the rog /
# thinkcentre / t14 visuals stay in sync.  The rofile-based variant
# in `btop-file.nix` is used by the other Linux hosts instead.
#
# Imported by `hosts/t14/home/omarchy.nix`. The `glats` theme
# file is written by the shared `home-linux/btop-theme.nix` module
# (also imported by `omarchy.nix`).
{
  lib,
  ...
}:
{
  programs.btop.settings = {
    color_theme = lib.mkForce "glats";
    theme_background = lib.mkForce true;
    truecolor = lib.mkForce true;
    force_tty = lib.mkForce false;
    presets = lib.mkForce "cpu:1:default,proc:0:default cpu:0:default,mem:0:default,net:0:default cpu:0:block,net:0:tty";
    vim_keys = lib.mkForce false;
    rounded_corners = lib.mkForce true;
    terminal_sync = lib.mkForce true;
    graph_symbol = lib.mkForce "braille";
    graph_symbol_cpu = lib.mkForce "default";
    graph_symbol_mem = lib.mkForce "default";
    graph_symbol_net = lib.mkForce "default";
    graph_symbol_proc = lib.mkForce "default";
    shown_boxes = lib.mkForce "cpu gpu mem net proc";
    update_ms = lib.mkForce 200;
    proc_sorting = lib.mkForce "cpu lazy";
    proc_reversed = lib.mkForce false;
    proc_tree = lib.mkForce false;
    proc_colors = lib.mkForce true;
    proc_gradient = lib.mkForce true;
    proc_per_core = lib.mkForce false;
    proc_mem_bytes = lib.mkForce true;
    proc_cpu_graphs = lib.mkForce true;
    proc_info_smaps = lib.mkForce false;
    proc_left = lib.mkForce false;
    show_uptime = lib.mkForce true;
    show_cpu_watts = lib.mkForce true;
    check_temp = lib.mkForce true;
    cpu_sensor = lib.mkForce "Auto";
    show_coretemp = lib.mkForce true;
    cpu_core_map = lib.mkForce "";
    temp_scale = lib.mkForce "celsius";
    base_10_sizes = lib.mkForce false;
    show_cpu_freq = lib.mkForce true;
    freq_mode = lib.mkForce "first";
    clock_format = lib.mkForce "%X";
    background_update = lib.mkForce true;
    custom_cpu_name = lib.mkForce "";
    disks_filter = lib.mkForce "";
    mem_graphs = lib.mkForce true;
    mem_below_net = lib.mkForce false;
    zfs_arc_cached = lib.mkForce true;
    show_swap = lib.mkForce true;
    swap_disk = lib.mkForce true;
    show_disks = lib.mkForce true;
    only_physical = lib.mkForce true;
    use_fstab = lib.mkForce true;
    zfs_hide_datasets = lib.mkForce false;
    disk_free_priv = lib.mkForce false;
    show_io_stat = lib.mkForce true;
    io_mode = lib.mkForce false;
    io_graph_combined = lib.mkForce false;
    io_graph_speeds = lib.mkForce "";
    net_download = lib.mkForce 100;
    net_upload = lib.mkForce 100;
    net_auto = lib.mkForce true;
    net_sync = lib.mkForce true;
    net_iface = lib.mkForce "";
    base_10_bitrate = lib.mkForce "Auto";
    show_battery = lib.mkForce true;
    selected_battery = lib.mkForce "Auto";
    show_battery_watts = lib.mkForce true;
    log_level = lib.mkForce "WARNING";
    save_config_on_exit = lib.mkForce false;
    gpu_mirror_graph = lib.mkForce true;
    shown_gpus = lib.mkForce "nvidia amd intel";
  };
}
