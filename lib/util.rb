def smart_resize_bounds(sw, sh, dw, dh)
  raise "dest width and dest height cannot both be nil!"  if dw.nil? && dh.nil?
  voff = 0.0; hoff = 0.0
  tdw = dw; tdh = dh;
  tsw = sw; tsh = sh;
  tdw = tdh * tsw / tsh if dw.nil?
  tdh = tdw * tsh / tsw if dh.nil?
  if !dw.nil? && !dh.nil?
    voff = tdh - (tsh * tdw) / tsw
    hoff = tdw - (tdh * tsw) / tsh
    voff = 0.0 if voff < 0.0
    hoff = 0.0 if hoff < 0.0
  end
  x = (hoff / 2.0).floor
  y = (voff / 2.0).floor
  w = (tdw - hoff).floor
  h = (tdh - voff).floor
  while true
    w += 1; next if w + x * 2 < dw
    w -= 1; next if w + x * 2 > dw
    h += 1; next if h + y * 2 < dh
    h -= 1; next if h + y * 2 > dh
    break
  end
  {x: x, y: y, w: w, h: h}
end
