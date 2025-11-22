import Astal from "gi://Astal?version=3.0";
import Gtk from "gi://Gtk?version=3.0";
import Gdk from "gi://Gdk?version=3.0";
import GdkPixbuf from "gi://GdkPixbuf";
import Gio from "gi://Gio";
import AstalIO from "gi://AstalIO?version=0.1";

// --- CONFIGURATION ---
const BACKGROUNDS_DIR =
  "/home/archy/.config/omarchy/current/theme/backgrounds/";
const CURRENT_BG_LINK = "/home/archy/.config/omarchy/current/background";

// --- LOGIC ---
function setWallpaper(filename) {
  const fullPath = BACKGROUNDS_DIR + filename;

  // 1. Link & Update Wallpaper
  AstalIO.Process.exec_async(
    `ln -nsf "${fullPath}" "${CURRENT_BG_LINK}"`,
    (out, err) => {
      if (err) print("Error linking wallpaper: " + err);
    }
  );
  AstalIO.Process.exec_async(`swww img -t any "${fullPath}"`, (out, err) => {
    if (err) print("Error setting wallpaper: " + err);
  });

  // 2. Quit the picker app immediately after selection
  Astal.Application.get_default().quit();
}

// --- COMPONENT: WALLPAPER CARD ---
function createCard(filename) {
  const fullPath = BACKGROUNDS_DIR + filename;
  const safeClassName = `img-${filename.replace(/[^a-zA-Z0-9]/g, "")}`;

  const button = new Gtk.Button();
  button.set_tooltip_text(filename);
  button.get_style_context().add_class("wallpaper-card");
  button.get_style_context().add_class(safeClassName);

  // Check if it's a GIF to use animated image
  const isGif = filename.toLowerCase().endsWith(".gif");

  if (isGif) {
    // Load and scale animated GIF properly
    const pixbufAnim = GdkPixbuf.PixbufAnimation.new_from_file(fullPath);

    // Get the static image to determine scaling
    const staticPixbuf = pixbufAnim.get_static_image();
    const origWidth = staticPixbuf.get_width();
    const origHeight = staticPixbuf.get_height();

    // Calculate scale to fit in 300x169
    const scaleW = 300 / origWidth;
    const scaleH = 169 / origHeight;
    const scale = Math.min(scaleW, scaleH);

    const newWidth = Math.floor(origWidth * scale);
    const newHeight = Math.floor(origHeight * scale);

    // Scale the static image for preview
    const scaledPixbuf = staticPixbuf.scale_simple(
      newWidth,
      newHeight,
      GdkPixbuf.InterpType.BILINEAR
    );

    const image = Gtk.Image.new_from_pixbuf(scaledPixbuf);

    const box = new Gtk.Box();
    box.set_size_request(300, 169);
    box.set_halign(Gtk.Align.CENTER);
    box.set_valign(Gtk.Align.CENTER);
    box.add(image);

    button.add(box);
    button.get_style_context().add_class("gif-card");
  } else {
    // Use CSS background for static images
    const cssProvider = new Gtk.CssProvider();
    cssProvider.load_from_data(
      `.${safeClassName} { background-image: url("${fullPath}"); }`
    );
    button
      .get_style_context()
      .add_provider(cssProvider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
  }

  button.connect("clicked", () => setWallpaper(filename));
  return button;
}

// --- LOAD WALLPAPER CARDS ---
function loadWallpaperCards() {
  try {
    const dir = Gio.File.new_for_path(BACKGROUNDS_DIR);
    const enumerator = dir.enumerate_children(
      "standard::name",
      Gio.FileQueryInfoFlags.NONE,
      null
    );

    const cards = [];
    let fileInfo;
    while ((fileInfo = enumerator.next_file(null)) !== null) {
      const filename = fileInfo.get_name();
      if (filename.match(/\.(jpg|jpeg|png|webp|gif)$/i)) {
        cards.push(createCard(filename));
      }
    }

    return cards.length > 0
      ? cards
      : [new Gtk.Label({ label: "No images found" })];
  } catch (e) {
    print("Error loading wallpapers: " + e.message);
    return [
      new Gtk.Label({ label: "Could not load images.\nCheck path in app.js" }),
    ];
  }
}

// --- MAIN APP ---
const app = new Astal.Application({
  instanceName: "wallpaper-picker",
});

let selectedIndex = 0;
let cardWidgets = [];

app.connect("activate", () => {
  // Load CSS
  const cssProvider = new Gtk.CssProvider();
  cssProvider.load_from_path("./style.css");
  Gtk.StyleContext.add_provider_for_screen(
    Gdk.Screen.get_default(),
    cssProvider,
    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
  );

  const container = new Gtk.Box({
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 15,
  });
  container.get_style_context().add_class("picker-container");

  const title = new Gtk.Label({
    label: "Select Wallpaper",
    xalign: 0,
  });
  title.get_style_context().add_class("picker-title");

  const scroll = new Gtk.ScrolledWindow({
    hscrollbar_policy: Gtk.PolicyType.ALWAYS,
    vscrollbar_policy: Gtk.PolicyType.NEVER,
  });
  scroll.set_min_content_width(800);
  scroll.set_min_content_height(240);

  const cardBox = new Gtk.Box({
    spacing: 15,
    orientation: Gtk.Orientation.HORIZONTAL,
  });

  // Load cards
  const cards = loadWallpaperCards();
  cardWidgets = cards;
  cards.forEach((card) => cardBox.add(card));

  // Select first card by default
  if (cardWidgets.length > 0 && cardWidgets[0] instanceof Gtk.Button) {
    cardWidgets[0].get_style_context().add_class("selected");
  }

  scroll.add(cardBox);
  container.add(title);
  container.add(scroll);

  const win = new Astal.Window({
    application: app,
    name: "wallpaper-picker",
    anchor: Astal.WindowAnchor.BOTTOM,
    margin_bottom: 50,
    keymode: Astal.Keymode.ON_DEMAND,
  });

  // Add Escape key handler to quit
  win.connect("key-press-event", (widget, event) => {
    const keyval = event.get_keyval()[1];

    if (keyval === Gdk.KEY_Escape) {
      Astal.Application.get_default().quit();
      return true;
    }

    // Arrow key navigation
    if (cardWidgets.length > 0 && cardWidgets[0] instanceof Gtk.Button) {
      if (keyval === Gdk.KEY_Left) {
        // Remove selected class from current
        cardWidgets[selectedIndex].get_style_context().remove_class("selected");
        // Move left
        selectedIndex =
          selectedIndex > 0 ? selectedIndex - 1 : cardWidgets.length - 1;
        // Add selected class to new
        cardWidgets[selectedIndex].get_style_context().add_class("selected");

        // Scroll to selected card
        const adjustment = scroll.get_hadjustment();
        const cardX = selectedIndex * (300 + 15); // card width + spacing
        adjustment.set_value(cardX - 100);

        return true;
      }

      if (keyval === Gdk.KEY_Right) {
        // Remove selected class from current
        cardWidgets[selectedIndex].get_style_context().remove_class("selected");
        // Move right
        selectedIndex =
          selectedIndex < cardWidgets.length - 1 ? selectedIndex + 1 : 0;
        // Add selected class to new
        cardWidgets[selectedIndex].get_style_context().add_class("selected");

        // Scroll to selected card
        const adjustment = scroll.get_hadjustment();
        const cardX = selectedIndex * (300 + 15); // card width + spacing
        adjustment.set_value(cardX - 100);

        return true;
      }

      if (keyval === Gdk.KEY_Return || keyval === Gdk.KEY_KP_Enter) {
        // Activate selected card
        cardWidgets[selectedIndex].clicked();
        return true;
      }
    }

    return false;
  });

  win.add(container);
  win.show_all();
});

app.run([]);
