# Hyprland Cascade Layout

<img width="720" height="405" alt="stacked" src="https://github.com/user-attachments/assets/bdcb520f-d8a9-41e6-95d7-fb927e004a55" />
<br><br/>
  
### A cascade style layout for Hyprland.  
Requires [my patched Hyprland fork](https://github.com/kvrtco/Hyprland-overlap-hit-patch) to work properly. **Loads on vanilla Hyprland, just isn't usable** (Clicking on a focused window shifts focus to the window underneath it, making normal use impractical).
<br>
This happens because vanilla Hyprland checks overlapping windows from the bottom of the z-order up, so it can focus a covered window instead of the visible one on top.
<br>

Build the fork with Cmake and create .desktop session entry for your display manager.
