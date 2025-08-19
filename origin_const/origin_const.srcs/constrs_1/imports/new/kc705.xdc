# =========================================
# KC705 专用 XDC 文件 - 80MHz版本
# 端口名称与 VHDL 保持完全一致
# =========================================

# ===========================================
# 时钟约束 (最重要！)
# ===========================================
# 1. 创建200MHz差分输入时钟约束
create_clock -period 5.000 -name clk_200_pin -waveform {0.000 2.500} [get_ports clk_p]

# 2. 创建80MHz生成时钟约束（通过MMCM生成）
create_generated_clock -name clk_80 \
  -source [get_pins mmcm_inst/CLKIN1] \
  -multiply_by 5 -divide_by 20 \
  [get_pins mmcm_inst/CLKOUT0]

# 3. 设置时钟不确定性
set_clock_uncertainty -setup 0.200 [get_clocks clk_200_pin]
set_clock_uncertainty -hold 0.100 [get_clocks clk_200_pin]
set_clock_uncertainty -setup 0.200 [get_clocks clk_80]
set_clock_uncertainty -hold 0.100 [get_clocks clk_80]

# 4. 设置时钟域分组（200MHz和80MHz异步）
set_clock_groups -asynchronous \
  -group [get_clocks clk_200_pin] \
  -group [get_clocks clk_80]

# ===========================================
# 差分时钟引脚约束
# ===========================================
# PadFunction: IO_L12P_T1_MRCC_33 
set_property VCCAUX_IO DONTCARE [get_ports {clk_p}]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {clk_p}]
set_property PACKAGE_PIN AD12 [get_ports {clk_p}]

# PadFunction: IO_L12N_T1_MRCC_33 
set_property VCCAUX_IO DONTCARE [get_ports {clk_n}]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {clk_n}]
set_property PACKAGE_PIN AD11 [get_ports {clk_n}]

# ===========================================
# 复位按钮约束
# ===========================================
# 板载复位按钮 (CPU_RESET, Bank 15, LVCMOS25)
set_property PACKAGE_PIN G12 [get_ports arst]
set_property IOSTANDARD LVCMOS25 [get_ports arst]

# 复位信号为异步，设置false path
set_false_path -from [get_ports arst]

# ===========================================
# UART 串口约束
# ===========================================
# UART 串口 (用于输出星座图数据和统计信息, LVCMOS33)
set_property PACKAGE_PIN M19 [get_ports rx]
set_property IOSTANDARD LVCMOS33 [get_ports rx]

set_property PACKAGE_PIN K24 [get_ports tx]
set_property IOSTANDARD LVCMOS33 [get_ports tx]

# UART输入输出延迟约束（基于80MHz工作时钟）
set_input_delay -clock clk_80 -min 0.000 [get_ports rx]
set_input_delay -clock clk_80 -max 2.000 [get_ports rx]
set_output_delay -clock clk_80 -min 0.000 [get_ports tx]
set_output_delay -clock clk_80 -max 4.000 [get_ports tx]

# ===========================================
# LED 输出约束
# ===========================================
set_property PACKAGE_PIN AB8  [get_ports led_clk]
set_property PACKAGE_PIN AA8  [get_ports led_rst]
set_property PACKAGE_PIN AC9  [get_ports led_test]

set_property IOSTANDARD LVCMOS18 [get_ports led_clk]
set_property IOSTANDARD LVCMOS18 [get_ports led_rst]
set_property IOSTANDARD LVCMOS18 [get_ports led_test]

# LED输出延迟约束（基于80MHz工作时钟）
set_output_delay -clock clk_80 -min 0.000 [get_ports {led_clk led_rst led_test}]
set_output_delay -clock clk_80 -max 5.000 [get_ports {led_clk led_rst led_test}]

# ===========================================
# MMCM相关约束
# ===========================================
# MMCM锁定时间约束
set_false_path -to [get_pins -hierarchical *mmcm*/RST]
set_false_path -from [get_pins -hierarchical *mmcm*/LOCKED]
# ===========================================
# 时序优化设置
# ===========================================
# 针对关键路径的优化
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets clk_200]
# 注释掉clk_80的BACKBONE设置，因为它是生成时钟
# set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets clk_80]

# 如果需要进一步优化，可以取消以下注释：
# 设置关键路径的最大延迟（80MHz = 12.5ns周期，允许10ns）
# set_max_delay -from [get_cells system_inst/channel_inst/phase_noise_inst/phase_reg*] \
#               -to [get_cells system_inst/channel_inst/phase_noise_inst/*] 10.0

# 多周期路径设置（如果某些路径可以使用多个时钟周期）
# set_multicycle_path -setup 2 -from [get_cells system_inst/channel_inst/phase_noise_inst/gng_inst*] \
#                     -to [get_cells system_inst/channel_inst/phase_noise_inst/phase_reg*]
# set_multicycle_path -hold 1 -from [get_cells system_inst/channel_inst/phase_noise_inst/gng_inst*] \
#                     -to [get_cells system_inst/channel_inst/phase_noise_inst/phase_reg*]

# ===========================================
# 调试选项（可选）
# ===========================================
# 如果需要调试，可以取消以下注释添加ILA：
# create_debug_core u_ila_0 ila
# set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
# set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
# set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
# set_property port_width 16 [get_debug_ports u_ila_0/probe0]
# connect_debug_port u_ila_0/probe0 [get_nets {system_inst/channel_inst/phase_noise_inst/phase[0][*]}]

# ===========================================
# 综合和实现策略设置
# ===========================================
# 设置更高的优化级别
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks RTSTAT-10]