project('vlauncher', 'vala', 'c')

dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gtk4'),
    dependency('libadwaita-1'),
]

sources = files('vlauncher.vala')

executable('vlauncher', sources, dependencies: dependencies, install: true)
