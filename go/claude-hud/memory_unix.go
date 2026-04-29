//go:build !windows

package main

import (
	"bufio"
	"os"
	"strconv"
	"strings"
)

func readSystemMemory() (total, used uint64, ok bool) {
	f, err := os.Open("/proc/meminfo")
	if err != nil {
		return 0, 0, false
	}
	defer f.Close()

	var memTotal, memAvailable uint64
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		switch fields[0] {
		case "MemTotal:":
			if n, err := strconv.ParseUint(fields[1], 10, 64); err == nil {
				memTotal = n * 1024 // kB to bytes
			}
		case "MemAvailable:":
			if n, err := strconv.ParseUint(fields[1], 10, 64); err == nil {
				memAvailable = n * 1024
			}
		}
		if memTotal > 0 && memAvailable > 0 {
			break
		}
	}
	if memTotal == 0 {
		return 0, 0, false
	}
	return memTotal, memTotal - memAvailable, true
}
