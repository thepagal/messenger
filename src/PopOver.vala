using GLib;
using Gtk;
using Granite.Widgets;

public class Ui.PopOver : CompositedWindow {

    protected int arrow_offset { get; set; default = 0; }
    protected const int ARROW_WIDTH = 20;
    protected const int ARROW_HEIGHT = 10;
    protected const int BORDER_RADIUS = 10;
    protected const int BORDER_WIDTH = 1;
    protected const int SHADOW_SIZE = 20;

    protected Granite.Drawing.BufferSurface? main_buffer = null;

    private bool dont_close = false;

    private Gtk.PositionType arrow_position = Gtk.PositionType.BOTTOM;    
    
    public Requisition get_size (Gtk.PositionType position) {
        var req = get_requisition ();
        if (position == PositionType.TOP || position == PositionType.BOTTOM) {
            req.height -= ARROW_HEIGHT;
        } else {
            req.width -= ARROW_HEIGHT;
        }
        return { req.width, req.height };
    }
     
    private bool button_release (Gdk.EventButton event) {
        close ();
        return false;
    }
    
    private bool key_release (Gdk.EventKey event) {
        if (Gdk.keyval_name (event.keyval) == "Escape") {
            close ();
        }
        return false;
    }
    
    private bool focus_out (Gdk.EventFocus event) {
        close ();
        return false;
    }
    
    //Code from Granite.Widgets.PopOver
    protected void cairo_popover (Cairo.Context cr, double x, double y, double width, double height, double border_radius) {
        double arrow_offset;
        var arrow_side_offset = ARROW_HEIGHT - SHADOW_SIZE;
        if (arrow_position == PositionType.TOP || arrow_position == PositionType.BOTTOM) {
            arrow_offset = (width - ARROW_WIDTH) / 2 + this.arrow_offset + x;
            height -= arrow_side_offset;
            if (arrow_position == PositionType.TOP) {
                y += arrow_side_offset;
            }
        } else {
            arrow_offset = (height - ARROW_WIDTH) / 2 + this.arrow_offset + y;
            width -= arrow_side_offset;
            if (arrow_position == PositionType.LEFT) {
                x += arrow_side_offset;
            }
        }

        cr.arc (x + border_radius, y + border_radius, border_radius, Math.PI, Math.PI * 1.5);
        if (arrow_position == PositionType.TOP) {
            cr.line_to (arrow_offset, y);
            cr.rel_line_to (ARROW_WIDTH / 2.0, -ARROW_HEIGHT);
            cr.rel_line_to (ARROW_WIDTH / 2.0, ARROW_HEIGHT);
        }
        cr.arc (x + width - border_radius, y + border_radius, border_radius, Math.PI * 1.5, Math.PI * 2.0);
        if (arrow_position == PositionType.RIGHT) {
            cr.line_to (x + width, arrow_offset);
            cr.rel_line_to (ARROW_HEIGHT, ARROW_WIDTH / 2.0);
            cr.rel_line_to (-ARROW_HEIGHT, ARROW_WIDTH / 2.0);
        }
        cr.arc (x + width - border_radius, y + height - border_radius, border_radius, 0, Math.PI * 0.5);
        if (arrow_position == PositionType.BOTTOM) {
            cr.line_to (arrow_offset + ARROW_WIDTH, y + height);
            cr.rel_line_to (-ARROW_WIDTH / 2.0, ARROW_HEIGHT);
            cr.rel_line_to (-ARROW_WIDTH / 2.0, -ARROW_HEIGHT);
        }
        cr.arc (x + border_radius, y + height - border_radius, border_radius, Math.PI * 0.5, Math.PI);
        if (arrow_position == PositionType.LEFT) {
            cr.line_to (x, arrow_offset + ARROW_WIDTH);
            cr.rel_line_to (-ARROW_HEIGHT, -ARROW_WIDTH / 2.0);
            cr.rel_line_to (ARROW_HEIGHT, -ARROW_WIDTH / 2.0);
        }
        cr.close_path ();
    }
    
    //Code from Granite.Widgets.PopOver
    void compute_shadow (int w, int h) {
          main_buffer = new Granite.Drawing.BufferSurface (w, h);
  
          // Shadow first
          cairo_popover (main_buffer.context, SHADOW_SIZE + BORDER_WIDTH / 2.0, SHADOW_SIZE + BORDER_WIDTH / 2.0,
                         w - SHADOW_SIZE * 2 - BORDER_WIDTH, h - SHADOW_SIZE * 2 - BORDER_WIDTH, BORDER_RADIUS);
          main_buffer.context.set_source_rgba (0.0, 0.0, 0.0, 0.4);
          main_buffer.context.fill_preserve ();
          main_buffer.exponential_blur (SHADOW_SIZE / 2 - 1); // rough approximation
  
          // Background
          main_buffer.context.set_source_rgba (1, 1, 1, 1);
          main_buffer.context.set_operator (Cairo.Operator.CLEAR);
          main_buffer.context.fill_preserve ();
  
          // Outer border
          main_buffer.context.set_operator (Cairo.Operator.SOURCE);
          main_buffer.context.set_line_width (BORDER_WIDTH);
          main_buffer.context.set_source_rgba (0.5, 0.5, 0.5, 0.5);
          main_buffer.context.stroke_preserve ();
      }
        
    public new void close (bool force = false) {
        if (force || !dont_close) {
            FocusGrabber.ungrab ();
            hide ();
        }
    }
    
    public void activate () {
        dont_close = true;
        show_all ();
        FocusGrabber.grab (get_window (), false, true);
        Timeout.add (200, () => {
            dont_close = false;
            return false;
        });
    }
    
    public PopOver () {
        type_hint = Gdk.WindowTypeHint.DOCK;
        skip_taskbar_hint = true;
        skip_pager_hint = true;
        set_keep_above (true);
        stick ();
        
        button_release_event.connect (button_release);
        key_release_event.connect (key_release);
        focus_out_event.connect (focus_out);
        size_allocate.connect(on_size_allocate);
        notify ["arrow-offset"].connect ((s, p) => {
            compute_shadow (old_w, old_h);
        });
    }
    
    //Code from Granite.Widgets.PopOver
    int old_w = 0;
    int old_h = 0;
    void on_size_allocate(Gtk.Allocation alloc)
    {
        int w = get_allocated_width();
        int h = get_allocated_height();
        if(old_w == w && old_h == h)
            return;

        compute_shadow (w, h);

        old_w = w;
        old_h = h;
    }
    
    //Code from Granite.Widgets.PopOver
    public override bool draw (Cairo.Context cr) {
        cr.new_path ();
        cr.append_path (main_buffer.context.copy_path ());
        cr.clip ();
        cr.set_source_rgba (1, 1, 1, 1);
        cr.paint ();
        var ret = base.draw (cr);
        cr.reset_clip ();
        cr.set_source_surface (main_buffer.surface, 0, 0);
        cr.paint ();
        return ret;
    }
    
    public void set_position (int x, int y, Gtk.PositionType arrow_pos) {
        arrow_position = arrow_pos;
        var w = width_request, h = height_request, cx = x + w / 2, cy = y + h / 2;
        Gdk.Rectangle rect;
        screen.get_monitor_geometry (screen.get_monitor_at_point (cx, cy), out rect);
        var offset_x = 0.clamp (rect.x - x, rect.x + rect.width - x - w);
        var offset_y = 0.clamp (rect.y - y, rect.y + rect.height - y - h);
        if (arrow_pos == Gtk.PositionType.BOTTOM || arrow_pos == Gtk.PositionType.TOP) {
            arrow_offset = -offset_x;
        } else {
            arrow_offset = -offset_y;
        }
        base.move (x + offset_x, y + offset_y);
    }
}

