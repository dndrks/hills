function redraw()
  screen.clear()
  screen.level(15)
  screen.move(64,32)
  screen.text_center('custom ugens installed')
  screen.move(64,42)
  screen.text_center('please restart norns')
  screen.update()
end