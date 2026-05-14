ioreg -rc IOMobileFramebufferShim | awk '/"IOMFBBrightnessLevel" =/ { printf "Brightness: %.0f%%\n", ($4 / 27515064) * 100; exit }'
