//go:build windows

package main

import (
	"unsafe"

	"golang.org/x/sys/windows"
)

type memStatusEx struct {
	Length               uint32
	MemoryLoad           uint32
	TotalPhys            uint64
	AvailPhys            uint64
	TotalPageFile        uint64
	AvailPageFile        uint64
	TotalVirtual         uint64
	AvailVirtual         uint64
	AvailExtendedVirtual uint64
}

func readSystemMemory() (total, used uint64, ok bool) {
	kernel32, err := windows.LoadDLL("kernel32.dll")
	if err != nil {
		return 0, 0, false
	}
	proc, err := kernel32.FindProc("GlobalMemoryStatusEx")
	if err != nil {
		return 0, 0, false
	}
	var ms memStatusEx
	ms.Length = uint32(unsafe.Sizeof(ms))
	r, _, _ := proc.Call(uintptr(unsafe.Pointer(&ms)))
	if r == 0 {
		return 0, 0, false
	}
	return ms.TotalPhys, ms.TotalPhys - ms.AvailPhys, true
}
