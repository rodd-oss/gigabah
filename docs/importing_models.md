# Key reasons how and why to import .blend files to godot.

*Godot recomended formats are .gltf and .gltb .
Also it can on the fly import animations, materials and models from .blend files, which makes all changes apear instantly in editor without any reimplementation in code.*

> #### if you are importing:
> - .glb binary
> - or .gltf text based with embeded binary.
> - or .gltf + .bin + textures.
>
> *You need to reimplement all logic to animations and manualy make new scene.
.blend file can contain multiple models with separate materials, textures and animations that will be automaticly configured.*

## Importing .blend files directly within Godot:
- Requires **Blender 3.0 or later** in default location.
    If blender instaled somwhere else:
    add filepath using Filesystem > Import > Blender > Blender 3 Path
- Import using godot.
- For update just save your .blend file in blender

## How to change contents of imported .blend model in godot:
> **No automatic file update will be posible of this node.**
- Right click on scene.
- Make Local.

## Importing other formats:
- Export separetly Model, Animations (Not needed for .gltf), Textures.
- Import them to godot.
- Add separate scene ModelName.tscn
- Make root node as Node3D
- Add AnimationPlayer if needed.
- Apply all animations, materials and textures.
- Configure specific data if needed.

*More precise guidlines for this project will be added in future.*

More info: [Godot docs](https://docs.godotengine.org/en/4.5/tutorials/assets_pipeline/)