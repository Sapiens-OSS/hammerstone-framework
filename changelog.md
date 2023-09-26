# 0.0.1 

The first release of Hammerstone

# 0.0.2

 - Added `resource:addResourceGroup`
 - Fixed errors related to usage of non-existent `mj:warning` method
 - Allowed default values in `saveState:getValueServer` and `saveState:getValueClient`
 - Completely rewrote the `saveState` system to allow a new, all-threads, table-based approach

# 0.0.3

 - Small updates to support the release of creative mode
 - Rewrote the 'action UI' system to allow better flexibility

# 0.0.4

- Exposes terrainTypes:addBaseType
- Expose terrainTypes:addVariation

# 0.0.5

 - Fix import issue in 0.0.4

# 1.0.0
 - The first release of the DDAPI, introducing an entire framework for data driven mod development.


# 1.1.0
 - Introduces a new 'shadow' syntax for mods to use
 - GameObject props are now based on `hs_object` component instead of `hs_buildable` component.

# 1.1.1

 - Fixed issue where craftables could load before resource groups, causing them to fail to generate
 - The 'loadOrder' argument for shadow:shadow will no longer overwrite a locally defined variable, if it's nil.

# 1.2.0

 - Code cleanup
 - Fixed issue where 'harvestables' were not generating correctly.
 - Added initial support for mobs
 - Fixed issue where craftables were no longer showing in the UI panel, likely re-introducing an issue with craftables using resource groups failing
 - Added support for 'defaultModelShouldOverrideResourceObject' in hs_buildable
 - Unknown storage_identifier no longer crashes without log message

# 1.3.0

 - Add 'resource:addResourceToGroup'
 - Add support for DDAPI resources to inject themselves into existing groups (i.e., fertilizer)
 - Fixed log spam when using `locale:getUnchecked'
 - Added support for 'disabledUntilAdditionalResearchDiscovered' inside of the `hs_buildable` component (research)

# 1.4.0

 - Added patching mods support
 - Patched mainThread/ui/actionUI to support more than 6 buttons in the wheel
 - Created the uiController to be able to retrieve all views
 - Patched all UI modules to register with the uiController
 - Fixed logging so it allows for more than one message arguments