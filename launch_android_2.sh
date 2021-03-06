#!/bin/bash

function launch_win()
{
vm_name=vm$1

#check if the vm is running or not
vm_ps=$(pgrep -a -f acrn-dm)
result=$(echo $vm_ps | grep "${vm_name}")
if [[ "$result" != "" ]]; then
  echo "$vm_name is running, can't create twice!"
  exit
fi
#-s 9,xhci,1-3 \
#add audio passthrough device
#echo "8086:9d71" > /sys/bus/pci/drivers/pci-stub/new_id
#echo "0000:00:1f.3" > /sys/bus/pci/drivers/pci-stub/bind

#for memsize setting
mem_size=2048M

acrn-dm -A -m $mem_size -s 0:0,hostbridge -s 1:0,lpc -l com1,stdio \
  -s 2,pci-gvt -G "$3" \
  -s 3,virtio-blk,./android.img \
  -U 495ae2e5-2603-4d64-af76-d4bc5a8ec0e5 \
  -s 4,virtio-net,tap2 \
  -s 6,virtio-console,@pty:pty_port \
  --ovmf ./OVMF.fd \
  -B "root=/dev/vda2 rw rootwait maxcpus=$2 nohpet console=tty0 console=hvc0 \
  console=ttyS0 no_timer_check ignore_loglevel log_buf_len=16M \
  consoleblank=0 tsc=reliable i915.avail_planes_per_pipe=$4 \
  i915.enable_hangcheck=0 i915.nuclear_pageflip=1 i915.enable_guc_loading=0 \
  i915.enable_guc_submission=0 i915.enable_guc=0" $vm_name
  
}

# offline SOS CPUs except BSP before launch UOS
for i in `ls -d /sys/devices/system/cpu/cpu[1-99]`; do
        online=`cat $i/online`
        idx=`echo $i | tr -cd "[1-99]"`
        echo cpu$idx online=$online
        if [ "$online" = "1" ]; then
                echo 0 > $i/online
		# during boot time, cpu hotplug may be disabled by pci_device_probe during a pci module insmod
		while [ "$online" = "1" ]; do
			sleep 1
			echo 0 > $i/online
			online=`cat $i/online`
		done
                echo $idx > /sys/class/vhm/acrn_vhm/offline_cpu
        fi
done

launch_win 2 1 "64 448 8" 0x00000F
