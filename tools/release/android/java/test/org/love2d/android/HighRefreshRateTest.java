package org.love2d.android;

import android.view.Display;
import java.lang.reflect.Constructor;

// Runs on a device or emulator (dalvikvm), against the real HighRefreshRate smali: see test_refresh_rate.sh.
public class HighRefreshRateTest {
    static int fails = 0, passes = 0;

    static void check(boolean ok, String what) {
        if (ok) passes++; else { fails++; System.out.println("FAIL " + what); }
    }

    static Display.Mode mode(int id, int w, int h, float hz) throws Exception {
        Constructor<Display.Mode> c = Display.Mode.class.getDeclaredConstructor(int.class, int.class, int.class, float.class);
        c.setAccessible(true);
        return c.newInstance(id, w, h, hz);
    }

    static int picked(Display.Mode cur, Display.Mode[] modes) {
        Display.Mode m = HighRefreshRate.pickMode(cur, modes);
        return m == null ? -1 : m.getModeId();
    }

    public static void main(String[] a) throws Exception {
        // Pixel 10 Pro XL: full resolution and 1080p, each at 120 and 60 Hz
        Display.Mode full120 = mode(1, 1344, 2992, 120f), hd120 = mode(2, 1080, 2404, 120f);
        Display.Mode full60 = mode(3, 1344, 2992, 60f), hd60 = mode(4, 1080, 2404, 60f);
        Display.Mode[] pixel = {full120, hd120, full60, hd60};
        check(picked(hd60, pixel) == 2, "phone at 1080p 60 Hz picks 1080p 120 Hz, not full resolution");
        check(picked(hd120, pixel) == 2, "phone at 1080p 120 Hz keeps 1080p");
        check(picked(full60, pixel) == 1, "phone at full resolution picks full resolution 120 Hz");

        // only another resolution has a high refresh rate: stay at the current resolution
        Display.Mode[] other = {mode(1, 1344, 2992, 120f), mode(2, 1080, 2404, 60f)};
        check(picked(other[1], other) == 2, "never switches resolution for a higher refresh rate");

        Display.Mode[] one = {mode(1, 1080, 2400, 90f)};
        check(picked(one[0], one) == 1, "single mode is kept");
        check(picked(mode(9, 720, 1600, 60f), one) == -1, "no mode at the current resolution picks nothing");
        check(picked(hd60, new Display.Mode[0]) == -1, "no modes picks nothing");

        System.out.println("passes=" + passes + " fails=" + fails);
        System.exit(fails == 0 ? 0 : 1);
    }
}
