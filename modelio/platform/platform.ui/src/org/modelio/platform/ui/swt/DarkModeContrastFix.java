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
package org.modelio.platform.ui.swt;

import com.modeliosoft.modelio.javadesigner.annotations.objid;
import org.eclipse.swt.SWT;
import org.eclipse.swt.custom.CTabFolder;
import org.eclipse.swt.custom.StyledText;
import org.eclipse.swt.widgets.Button;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Control;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Event;
import org.eclipse.swt.widgets.Label;
import org.eclipse.swt.widgets.List;
import org.eclipse.swt.widgets.Listener;
import org.eclipse.swt.widgets.Shell;
import org.eclipse.swt.widgets.Table;
import org.eclipse.swt.widgets.Text;
import org.eclipse.swt.widgets.ToolBar;
import org.eclipse.swt.widgets.Tree;
import org.modelio.platform.ui.UIColor;

/**
 * Forces a consistent light UI on macOS when the OS is in Dark Mode.
 * <p>
 * Modelio paints many tree/table items with fixed dark colors that assume a
 * light background. Under Dark Mode, SWT Cocoa gives Tree/Table a dark
 * background → near-invisible text. This helper restores light surfaces.
 */
@objid ("d4f8a01c-7b2e-4e91-9c1a-darkmodecontrast1")
public final class DarkModeContrastFix {
    @objid ("e5a9b12d-8c3f-4fa2-ad2b-darkmodecontrast2")
    private static boolean globalInstalled;

    @objid ("f6bac23e-9d40-40b3-be3c-darkmodecontrast3")
    private DarkModeContrastFix() {
        // utility
    }

    /**
     * @return true when we should force light-readable colors (cocoa + OS dark).
     */
    @objid ("07cbd34f-ae51-41c4-bf4d-darkmodecontrast4")
    public static boolean isNeeded() {
        if (!"cocoa".equals(SWT.getPlatform())) {
            return false;
        }
        try {
            return Display.isSystemDarkTheme();
        } catch (final Throwable t) {
            return true;
        }
    }

    /**
     * Install Display-level listener so Tree/Table widgets get light colors.
     * @param display current display
     */
    @objid ("18dce450-bf62-42d5-c05e-darkmodecontrast5")
    public static void installGlobal(final Display display) {
        if (display == null || display.isDisposed() || !isNeeded() || globalInstalled) {
            return;
        }
        globalInstalled = true;

        try {
            for (final Shell shell : display.getShells()) {
                forceLightShell(shell);
                apply(shell);
            }

            final Listener skinListener = new LightSurfaceFilter();
            display.addFilter(SWT.Skin, skinListener);
            display.addFilter(SWT.Show, skinListener);

            display.timerExec(500, new ApplyAllShells(display));
            display.timerExec(2000, new ApplyAllShells(display));
        } catch (final RuntimeException e) {
            globalInstalled = false;
            throw e;
        }
    }

    /**
     * Force light-readable foreground/background on a control tree.
     * @param root dialog contents, shell, or any composite
     */
    @objid ("29edf561-c073-43e6-d16f-darkmodecontrast6")
    public static void apply(final Control root) {
        if (root == null || root.isDisposed() || !isNeeded()) {
            return;
        }
        applyRecursive(root);
    }

    /**
     * Force the given shell onto Aqua / Light appearance.
     * @param shell dialog or main shell
     */
    @objid ("3afef672-d184-44f7-e27f-darkmodecontrast7")
    public static void forceLightShell(final Shell shell) {
        if (shell == null || shell.isDisposed() || !"cocoa".equals(SWT.getPlatform())) {
            return;
        }
        final Display display = shell.getDisplay();
        try {
            final Class<?> appearanceClass = Class.forName("org.eclipse.swt.widgets.Display$APPEARANCE");
            @SuppressWarnings({ "unchecked", "rawtypes" })
            final Object light = Enum.valueOf((Class) appearanceClass, "Light");

            final java.lang.reflect.Method setApp = Display.class.getDeclaredMethod("setAppAppearance", appearanceClass);
            setApp.setAccessible(true);
            setApp.invoke(display, light);

            final java.lang.reflect.Method setWindows = Display.class.getDeclaredMethod("setWindowsAppearance", appearanceClass);
            setWindows.setAccessible(true);
            setWindows.invoke(display, light);

            final java.lang.reflect.Method getAppearance = Display.class.getDeclaredMethod("getAppearance", appearanceClass);
            getAppearance.setAccessible(true);
            final Object nsAppearance = getAppearance.invoke(display, light);

            final java.lang.reflect.Field viewField = Control.class.getDeclaredField("view");
            viewField.setAccessible(true);
            final Object nsView = viewField.get(shell);
            if (nsView != null && nsAppearance != null) {
                final java.lang.reflect.Method windowMethod = nsView.getClass().getMethod("window");
                final Object nsWindow = windowMethod.invoke(nsView);
                if (nsWindow != null) {
                    final java.lang.reflect.Method setWindowAppearance = Display.class.getDeclaredMethod(
                            "setWindowAppearance",
                            Class.forName("org.eclipse.swt.internal.cocoa.NSWindow"),
                            Class.forName("org.eclipse.swt.internal.cocoa.NSAppearance"));
                    setWindowAppearance.setAccessible(true);
                    setWindowAppearance.invoke(display, nsWindow, nsAppearance);
                }
            }
        } catch (final ReflectiveOperationException | RuntimeException ignored) {
            // Best-effort
        }
    }

    @objid ("4b0f0783-e295-45a8-f38f-darkmodecontrast8")
    private static void applyRecursive(final Control control) {
        if (control == null || control.isDisposed()) {
            return;
        }
        applyLightSurface(control);
        if (control instanceof Composite) {
            for (final Control child : ((Composite) control).getChildren()) {
                applyRecursive(child);
            }
        }
    }

    @objid ("5c101894-f3a6-46b9-a4a0-darkmodecontrast9")
    private static void applyLightSurface(final Control control) {
        if (control == null || control.isDisposed()) {
            return;
        }

        try {
            if (control instanceof Tree
                    || control instanceof Table
                    || control instanceof List) {
                control.setBackground(UIColor.WHITE);
                control.setForeground(UIColor.BLACK);
            } else if (control instanceof CTabFolder) {
                final CTabFolder folder = (CTabFolder) control;
                folder.setBackground(UIColor.WHITE);
                folder.setForeground(UIColor.BLACK);
                folder.setSelectionBackground(UIColor.WHITE);
                folder.setSelectionForeground(UIColor.BLACK);
            } else if (control instanceof ToolBar) {
                control.setBackground(UIColor.WHITE);
                control.setForeground(UIColor.BLACK);
            } else if (control instanceof Text || control instanceof StyledText) {
                control.setForeground(UIColor.TEXT_WRITABLE_FG);
                control.setBackground(UIColor.TEXT_WRITABLE_BG);
            } else if (control instanceof Label) {
                control.setForeground(UIColor.BLACK);
            } else if (control instanceof Button) {
                control.setForeground(UIColor.BLACK);
            }
            // Do NOT paint every Composite white — that breaks diagram/canvas hosts.
        } catch (final RuntimeException ignored) {
            // Widget may reject colors; never crash startup/UI for cosmetics
        }
    }

    /**
     * Named listener (avoids anonymous $1 class missing after partial jar install).
     */
    @objid ("6d2129a5-04b7-47ca-b5b1-darkmodecontrasta")
    private static final class LightSurfaceFilter implements Listener {
        @Override
        public void handleEvent(final Event event) {
            if (event.widget instanceof Control) {
                applyLightSurface((Control) event.widget);
            }
        }
    }

    @objid ("7e323ab6-15c8-48db-c6c2-darkmodecontrastb")
    private static final class ApplyAllShells implements Runnable {
        private final Display display;

        ApplyAllShells(final Display display) {
            this.display = display;
        }

        @Override
        public void run() {
            if (this.display.isDisposed()) {
                return;
            }
            for (final Shell shell : this.display.getShells()) {
                forceLightShell(shell);
                apply(shell);
            }
        }
    }
}
