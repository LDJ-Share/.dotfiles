# Setup on a new machine

1. Create new VM (tested on Ubuntu 22.04 LTS)
2. Install git

    ```bash
    sudo apt-get update \
        && sudo apt --fix-broken install \
        && sudo apt install git \
        && sudo apt install cloud-guest-utils
    ```

3. Clone this repository to ~/.dotfiles and run setup

    ```bash
    git clone <>
    cd .dotfiles
    bash ./setup.sh
    ```

4. Run stow to deploy dotfiles

    ```bash
    stow .
    ```

## How to expand Ubuntu file system size

1. Delete all checkpoints
2. Power down machine
3. Go to VM's hyper-v settings and edit memory (settings -> SCSI Controller -> Hard Drive -> Edit).
4. Relaunch VM
5. Follow these instructions (from <https://linguist.is/2020/08/12/expand-ubuntu-disk-after-hyper-v-quick-create/>)

### Expanding inside VM after memory adjustment

It is quick and easy to use Hyper-V Quick Create to get an Ubuntu virtual machine running on a Windows 10 computer. However, if this method is used, you may end up with a tiny Ubuntu virtual disk that will not be useful for any serious work and it is less obvious than the initial setup how to increase the size of this disk.

These steps fix the problem:

Turn off the VM.
Use Hyper-V Manager to select the Settings of the Virtual Machine, select the Hard Drive option and Edit under Virtual hard disk. (If this option is disabled, you need to go back and delete any checkpoints for the VM in the Hyper-V Manager; just select the VM and right click the checkpoint in the checkpoint field below.)
Use the GUI to expand the drive to something reasonable, like 128 GB. Ubuntu now has space to expand into.
Start the VM again. Install Guest Utils:
sudo apt install cloud-guest-utils
If not using English, override locale settings to avoid issues with non-English locales:
LC_ALL=C
Expand the sda1 partition into the free space:
sudo growpart /dev/sda 1
(Note the space between sda and 1!)
Finally run resize2fs:
sudo resize2fs /dev/sda1
(No space between sda and 1 here!)
Now your Ubuntu drive is 128 GB.