# Hammerstone Data-Driven-API

The 'DDAPI' is a data-driven API for creating Hammerstone mods.

### Philosophy

In the base game of Sapiens, the data and logic for a "feature" is often spread across multiple files. For example, to create an apple, you might need the following:
 - `gameObject.lua` - Define the apple object
 - `resource.lua` - Give it a 'resource' definition for storage/crafting
 - `evolvingObject.lua` - Allow the apple to 'rot' away, or into a rotten variant
 - `storage.lua` - Allow the apple to be carried and stored in storage areas
 - ... and more!

With Hammerstone, we reverse this relationship. We believe you should be able to define your data in a single place, with a well-defined API. To create
an apple in Hammerstone, you would only need to create `apple.json`.

Inside this apple file, you define "components" describing the apple. For example, this component allows the apple to 'rot' into a rotten apple after some time:

```json
"hs_evolving_object": {
	"min_time": "5",
	"category": "rot",
	"transform_to": [
		"rotten_apple"
	]
}
```

### Config Types

At it's core, Hammerstone is a *json based API*. The reason we chose json is because it's a data-exchange format. That means there are a lot of tools like json schemas which
we can leverage. If you use our schemas you can get in-editor autocomplete, documentation, tool-tips, and linting.

However json isn't the best for complex items, which might require some programmatic-fields. In these cases you can also define your items in lua. We will read these lua files and evaluate them
as such.

# Getting Started with DDAPI

To get started, you need a live copy of Hammerstone beta, and a text editor like VSCode.