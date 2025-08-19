#!/usr/bin/env python3
"""
简洁干净的星座图脚本
固定1秒刷新频率，去除多余功能，保持干净显示
"""

import serial
import time
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import numpy as np
import struct
import threading
import queue
from collections import deque
import random


class CleanConstellation:
    def __init__(self, port='COM2', baudrate=9600, max_points=1500):
        self.port = port
        self.baudrate = baudrate
        self.max_points = max_points
        self.ser = None

        # Data storage
        self.i_data = deque(maxlen=max_points)
        self.q_data = deque(maxlen=max_points)
        self.data_queue = queue.Queue()

        # Control flags
        self.running = False
        self.capture_thread = None

        # 固定刷新策略
        self.refresh_interval = 1.0  # 固定1秒刷新
        self.last_refresh = time.time()
        self.refresh_count = 0

        # Statistics
        self.total_points = 0
        self.capture_rate = 0
        self.point_times = deque(maxlen=100)

        # Plot settings
        self.fig, self.ax = plt.subplots(figsize=(12, 10))
        self.scatter = None
        self.setup_plot()

    def setup_plot(self):
        """Setup clean plot interface"""
        self.ax.set_xlim(-80, 80)
        self.ax.set_ylim(-80, 80)
        self.ax.set_xlabel('I (In-phase)', fontsize=12)
        self.ax.set_ylabel('Q (Quadrature)', fontsize=12)
        self.ax.set_title('Real-time Constellation Diagram', fontsize=14)
        self.ax.grid(True, alpha=0.3)
        self.ax.set_aspect('equal')

        ideal_levels = [-45, -15, 15, 45]
        for i in ideal_levels:
            for q in ideal_levels:
                self.ax.plot(i, q, 'rx', markersize=8, alpha=0.3)

        # 初始化散点图 - 干净的蓝色点
        self.scatter = self.ax.scatter([], [], c='blue', alpha=0.7, s=25)

        # 添加简洁的信息文本
        self.info_text = self.ax.text(0.02, 0.98, '', transform=self.ax.transAxes,
                                      verticalalignment='top', fontsize=10,
                                      bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.8))

        # 简化的控制说明
        control_text = ("Controls:\n"
                        "Space: Pause/Resume\n"
                        "C: Clear data\n"
                        "R: Force refresh\n"
                        "Q: Exit")
        self.ax.text(0.98, 0.98, control_text, transform=self.ax.transAxes,
                     verticalalignment='top', horizontalalignment='right', fontsize=9,
                     bbox=dict(boxstyle='round', facecolor='lightblue', alpha=0.8))

    def connect(self):
        """Connect to serial port"""
        try:
            self.ser = serial.Serial(self.port, self.baudrate, timeout=0.1)
            print(f" Connected to {self.port}")
            return True
        except Exception as e:
            print(f" Connection failed: {e}")
            return False

    def set_noise_parameters(self, awgn_val=0x0800, pn_val=0x0100):
        """Set noise parameters"""
        if not self.ser:
            return False

        try:
            print(f" Setting noise: AWGN=0x{awgn_val:04X}, PN=0x{pn_val:04X}")

            commands = [
                [0x03, 0x00, awgn_val & 0xFF],
                [0x03, 0x01, (awgn_val >> 8) & 0xFF],
                [0x03, 0x02, pn_val & 0xFF],
                [0x03, 0x03, (pn_val >> 8) & 0xFF],
                [0x00]  # Reset
            ]

            for cmd in commands:
                self.ser.write(bytes(cmd))
                time.sleep(0.1)

            time.sleep(1)
            print(" Noise parameters set")
            return True
        except Exception as e:
            print(f" Parameter setting failed: {e}")
            return False

    def power_refresh(self):
        """强力刷新策略"""
        if not self.ser:
            return False

        try:
            # 双重重置
            for i in range(2):
                self.ser.write(bytes([0x00]))  # Reset
                time.sleep(0.1)

            # 存储命令
            self.ser.write(bytes([0x01]))  # Store
            time.sleep(0.15)

            # 双重触发
            for i in range(2):
                self.ser.write(bytes([0x06]))  # Trigger
                time.sleep(0.1)

            self.refresh_count += 1
            print(f" Power refresh #{self.refresh_count}")
            return True

        except Exception as e:
            print(f" Power refresh failed: {e}")
            return False

    def read_constellation_point(self, addr):
        """Read single constellation point"""
        if not self.ser:
            return None, None

        try:
            self.ser.write(bytes([0x05, addr & 0xFF]))
            time.sleep(0.008)

            response = self.ser.read(2)
            if len(response) == 2:
                i_val = struct.unpack('b', response[0:1])[0]
                q_val = struct.unpack('b', response[1:2])[0]
                return i_val, q_val
        except Exception as e:
            pass

        return None, None

    def capture_worker(self):
        """数据采集线程"""
        print(" Starting capture...")

        addr = 0
        successful_reads = 0

        while self.running:
            current_time = time.time()

            # 固定1秒间隔刷新
            if current_time - self.last_refresh > self.refresh_interval:
                print(f" Refresh (1.0s interval)")
                self.power_refresh()
                self.last_refresh = current_time
                addr = random.randint(0, 50)
                successful_reads = 0

            # 每100个点批量刷新
            if successful_reads > 0 and successful_reads % 100 == 0:
                print(f" Batch refresh ({successful_reads} reads)")
                self.power_refresh()
                addr = random.randint(0, 100)

            # 读取数据
            i_val, q_val = self.read_constellation_point(addr)

            if i_val is not None and q_val is not None:
                current_time = time.time()
                self.point_times.append(current_time)

                self.data_queue.put((i_val, q_val, current_time))
                successful_reads += 1

                # 混合地址策略
                if successful_reads % 3 == 0:
                    addr = random.randint(0, 255)
                else:
                    addr = (addr + 1) % 256

            else:
                time.sleep(0.005)

    def start_capture(self):
        """Start data capture"""
        if self.running:
            return

        self.running = True
        self.capture_thread = threading.Thread(target=self.capture_worker, daemon=True)
        self.capture_thread.start()

    def stop_capture(self):
        """Stop data capture"""
        self.running = False
        if self.capture_thread and self.capture_thread.is_alive():
            self.capture_thread.join(timeout=1)

    def update_plot(self, frame):
        """Update plot"""
        new_points = 0
        while not self.data_queue.empty():
            try:
                i_val, q_val, timestamp = self.data_queue.get_nowait()
                self.i_data.append(i_val)
                self.q_data.append(q_val)
                new_points += 1
                self.total_points += 1
            except queue.Empty:
                break

        # Calculate capture rate
        current_time = time.time()
        if len(self.point_times) > 1:
            time_window = 8
            recent_times = [t for t in self.point_times if current_time - t < time_window]
            if len(recent_times) > 1:
                self.capture_rate = len(recent_times) / time_window

        # 简洁的散点图更新 - 纯蓝色点
        if len(self.i_data) > 0:
            offsets = list(zip(self.i_data, self.q_data))
            self.scatter.set_offsets(offsets)
            self.scatter.set_color('blue')  # 统一蓝色

        # 简洁的信息显示
        if len(self.i_data) > 0:
            unique_points = len(set(zip(self.i_data, self.q_data)))

            recent_i = list(self.i_data)[-100:] if len(self.i_data) >= 100 else list(self.i_data)
            recent_q = list(self.q_data)[-100:] if len(self.q_data) >= 100 else list(self.q_data)

            i_range = max(recent_i) - min(recent_i) if recent_i else 0
            q_range = max(recent_q) - min(recent_q) if recent_q else 0

            info = (f"Total: {self.total_points}\n"
                    f"Display: {len(self.i_data)}\n"
                    f"Unique: {unique_points}\n"
                    f"Refreshes: {self.refresh_count}\n"
                    f"Rate: {self.capture_rate:.1f} pts/sec\n"
                    f"I range: {i_range}, Q range: {q_range}\n"
                    f"New: {new_points}\n"
                    f"Status: {'Running' if self.running else 'Paused'}")
        else:
            info = "Waiting for data..."

        self.info_text.set_text(info)
        return [self.scatter, self.info_text]

    def on_key_press(self, event):
        """简化的键盘控制"""
        if event.key == ' ':  # 暂停/继续
            if self.running:
                self.stop_capture()
                print(" Paused")
            else:
                self.start_capture()
                print(" Resumed")

        elif event.key == 'c':  # 清除数据
            self.i_data.clear()
            self.q_data.clear()
            self.total_points = 0
            print(" Data cleared")

        elif event.key == 'r':  # 手动刷新
            if self.running:
                self.power_refresh()
                print(" Manual refresh")

        elif event.key == 'q':  # 退出
            self.stop_capture()
            plt.close('all')
            print(" Exiting")

    def run(self, awgn_val=0x0800, pn_val=0x0100):
        """运行星座图显示"""
        print(" Starting Clean Constellation Display")
        print("=" * 50)

        if not self.connect():
            return

        if not self.set_noise_parameters(awgn_val, pn_val):
            return

        # 初始刷新
        print(" Initial refresh...")
        self.power_refresh()
        time.sleep(1.5)

        print("Controls: Space=Pause, C=Clear, R=Refresh, Q=Quit")

        self.fig.canvas.mpl_connect('key_press_event', self.on_key_press)
        self.start_capture()

        self.ani = animation.FuncAnimation(self.fig, self.update_plot,
                                           interval=80, blit=False, cache_frame_data=False)

        plt.tight_layout()
        plt.show()

        self.stop_capture()
        if self.ser:
            self.ser.close()
        print(" Program finished")


def main():
    """主函数"""
    print(" Clean Constellation Display")
    print("=" * 50)

    port = input("Enter serial port (default COM2): ").strip() or 'COM2'

    try:
        awgn_input = input("Enter AWGN level (hex, default 0800): ").strip()
        awgn_val = int(awgn_input, 16) if awgn_input else 0x0800
    except ValueError:
        awgn_val = 0x0800

    try:
        pn_input = input("Enter PN level (hex, default 0100): ").strip()
        pn_val = int(pn_input, 16) if pn_input else 0x0100
    except ValueError:
        pn_val = 0x0100

    constellation = CleanConstellation(port=port, max_points=1500)

    try:
        constellation.run(awgn_val=awgn_val, pn_val=pn_val)
    except KeyboardInterrupt:
        print("\n User interrupted")
    except Exception as e:
        print(f" Error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()