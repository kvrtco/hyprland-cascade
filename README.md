# Hyprland Cascade Layout

https://github.com/user-attachments/assets/5fab7370-9322-4f43-9ab6-35dd7e4aca3a
  
### A cascade style layout for Hyprland.  
Requires [my patched Hyprland fork](https://github.com/kvrtco/Hyprland-overlap-hit-patch) to work properly. **Loads on vanilla Hyprland, just isn't usable** (Clicking on a focused window shifts focus to the window underneath it, making normal use impractical).
<br>
This happens because vanilla Hyprland checks overlapping windows from the bottom of the z-order up, so it can focus a covered window instead of the visible one on top.
<br>

Build the fork with Cmake and create .desktop session entry for your display manager.
