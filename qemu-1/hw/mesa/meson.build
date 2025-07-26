mesa_sources = files(
  'extensions_table.c',
  'mesagl_blit.c',
  'mesagl_impl.c',
  'mesapt_mm.c',
  'mglmapbo.c',
  'mglvarry.c',
  'szgldata.c',
  'tokglstr.c',
)

# Platform-specific Mesa GL context implementations
if host_machine.system() == 'darwin'
  # macOS uses SDL-based implementation for better compatibility
  mesa_sources += files('mglcntx_sdlgl.c')
elif host_machine.system() == 'linux'
  # Linux can use either SDL or native GLX implementation
  mesa_sources += files('mglcntx_linux.c')
elif host_machine.system() == 'windows'
  # Windows uses native WGL implementation
  mesa_sources += files('mglcntx_mingw.c')
else
  # Fallback to SDL for other platforms
  mesa_sources += files('mglcntx_sdlgl.c')
endif

i386_system_ss.add(mesa_sources)
