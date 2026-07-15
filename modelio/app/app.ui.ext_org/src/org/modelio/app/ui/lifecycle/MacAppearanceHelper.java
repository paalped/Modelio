/* 
 * Copyright 2013-2020 Modeliosoft
 * 
 * This file is part of Modelio.
 * 
 * Modelio is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * Modelio is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with Modelio.  If not, see <http://www.gnu.org/licenses/>.
 * 
 */
package org.modelio.app.ui.lifecycle;

import java.lang.reflect.Method;
import com.modeliosoft.modelio.javadesigner.annotations.objid;
import org.eclipse.swt.SWT;
import org.eclipse.swt.widgets.Display;
import org.modelio.app.ui.plugin.AppUi;
import org.modelio.platform.ui.swt.DarkModeContrastFix;

/**
 * Forces a light (Aqua) appearance on macOS and installs contrast fixes for
 * Tree/Table/dialog widgets when the OS is in Dark Mode.
 */
@objid ("a7c3e1f0-2b4d-4f91-9e1a-macappearance01")
final class MacAppearanceHelper {
    @objid ("b8d4f201-3c5e-4fa2-af2b-macappearance02")
    private MacAppearanceHelper() {
        // utility
    }

    /**
     * If running on cocoa, force SWT Light appearance and install global
     * light-surface corrections for Dark Mode.
     */
    @objid ("c9e50312-4d6f-40b3-bc3c-macappearance03")
    static void forceLightAppearance() {
        if (!"cocoa".equals(SWT.getPlatform())) {
            return;
        }
        final Display display = Display.getCurrent();
        if (display == null || display.isDisposed()) {
            return;
        }
        try {
            final Class<?> appearanceClass = Class.forName("org.eclipse.swt.widgets.Display$APPEARANCE");
            @SuppressWarnings({ "unchecked", "rawtypes" })
            final Object light = Enum.valueOf((Class) appearanceClass, "Light");

            final Method setApp = Display.class.getDeclaredMethod("setAppAppearance", appearanceClass);
            setApp.setAccessible(true);
            setApp.invoke(display, light);

            final Method setWindows = Display.class.getDeclaredMethod("setWindowsAppearance", appearanceClass);
            setWindows.setAccessible(true);
            setWindows.invoke(display, light);

            AppUi.LOG.info("macOS: forced SWT Light appearance (Dark Mode workaround)");
        } catch (final ReflectiveOperationException | RuntimeException e) {
            AppUi.LOG.warning("macOS: could not force Light appearance: %s", e.toString());
        }

        DarkModeContrastFix.installGlobal(display);
    }
}
