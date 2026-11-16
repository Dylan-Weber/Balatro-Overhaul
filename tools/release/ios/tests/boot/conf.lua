love.conf = function(t)
	t.identity = "BalatroOverhaulIOSBoot"
	t.version = "11.5"
	t.console = false
	t.title = "Balatro Overhaul iOS boot test"
	t.window.width = tonumber(os.getenv("IOS_BOOT_W") or "") or 1334
	t.window.height = tonumber(os.getenv("IOS_BOOT_H") or "") or 750
	t.window.fullscreen = false
	t.window.highdpi = false
end
