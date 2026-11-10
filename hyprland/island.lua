-- Island is a layer-shell popup. Its background alpha follows Omarchy's
-- [popups] theme colors; blur strength follows Hyprland's decoration.blur.
hl.layer_rule({
  match = { namespace = "^omarchy-island-popup$" },
  blur = true,
  -- The native surface covers the output, but only its card has alpha.
  -- Do not blur the transparent area outside the card.
  ignore_alpha = 0.05,
})
