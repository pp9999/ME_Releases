if GamePlugin == nil then return end
GamePlugin.AchievementDescriptionType = GamePlugin.AchievementDescriptionType or {}
GamePlugin.AchievementHiddenType = GamePlugin.AchievementHiddenType or {}
GamePlugin.AchievementProgressType = GamePlugin.AchievementProgressType or {}
GamePlugin.AnimationDuplicateBehaviour = GamePlugin.AnimationDuplicateBehaviour or {}
GamePlugin.BoxCornerType = GamePlugin.BoxCornerType or {}
GamePlugin.Camera = GamePlugin.Camera or {}
GamePlugin.Chat = GamePlugin.Chat or {}
GamePlugin.ChatType = GamePlugin.ChatType or {}
GamePlugin.EntityType = GamePlugin.EntityType or {}
GamePlugin.Event = GamePlugin.Event or {}
GamePlugin.GameKey = GamePlugin.GameKey or {}
GamePlugin.GameState = GamePlugin.GameState or {}
GamePlugin.GrandExchange = GamePlugin.GrandExchange or {}
GamePlugin.GrandExchangeOfferStage = GamePlugin.GrandExchangeOfferStage or {}
GamePlugin.GrandExchangeOfferType = GamePlugin.GrandExchangeOfferType or {}
GamePlugin.HeightOffsetType = GamePlugin.HeightOffsetType or {}
GamePlugin.HintList = GamePlugin.HintList or {}
GamePlugin.Inventory = GamePlugin.Inventory or {}
GamePlugin.Keyboard = GamePlugin.Keyboard or {}
GamePlugin.LocList = GamePlugin.LocList or {}
GamePlugin.LocShapeType = GamePlugin.LocShapeType or {}
GamePlugin.MapElementHorizontalAlign = GamePlugin.MapElementHorizontalAlign or {}
GamePlugin.MapElementTextSize = GamePlugin.MapElementTextSize or {}
GamePlugin.MapElementVerticalAlign = GamePlugin.MapElementVerticalAlign or {}
GamePlugin.MiniMenu = GamePlugin.MiniMenu or {}
GamePlugin.MiniMenuActionType = GamePlugin.MiniMenuActionType or {}
GamePlugin.MiniMenuActionVerbType = GamePlugin.MiniMenuActionVerbType or {}
GamePlugin.MiniMenuEntryType = GamePlugin.MiniMenuEntryType or {}
GamePlugin.ModifierKey = GamePlugin.ModifierKey or {}
GamePlugin.Mouse = GamePlugin.Mouse or {}
GamePlugin.NPCList = GamePlugin.NPCList or {}
GamePlugin.ObjStackList = GamePlugin.ObjStackList or {}
GamePlugin.ObjStackType = GamePlugin.ObjStackType or {}
GamePlugin.Player = GamePlugin.Player or {}
GamePlugin.PlayerList = GamePlugin.PlayerList or {}
GamePlugin.PluginResourceLoadResult = GamePlugin.PluginResourceLoadResult or {}
GamePlugin.PostAnimMove = GamePlugin.PostAnimMove or {}
GamePlugin.PreAnimMove = GamePlugin.PreAnimMove or {}
GamePlugin.QuestDifficulty = GamePlugin.QuestDifficulty or {}
GamePlugin.QuestType = GamePlugin.QuestType or {}
GamePlugin.RotationType = GamePlugin.RotationType or {}
GamePlugin.ScreenConvert = GamePlugin.ScreenConvert or {}
GamePlugin.ShapeList = GamePlugin.ShapeList or {}
GamePlugin.SkillType = GamePlugin.SkillType or {}
GamePlugin.SystemKey = GamePlugin.SystemKey or {}
GamePlugin.ValueType = GamePlugin.ValueType or {}
GamePlugin.World = GamePlugin.World or {}
GamePlugin.audio = GamePlugin.audio or {}
GamePlugin.config = GamePlugin.config or {}
GamePlugin.id = GamePlugin.id or {}
GamePlugin.ui = GamePlugin.ui or {}
GamePlugin.utils = GamePlugin.utils or {}
GamePlugin.var = GamePlugin.var or {}
GamePlugin.Event.ChatMessage = GamePlugin.Event.ChatMessage or {}
GamePlugin.Event.ContentLayerReady = GamePlugin.Event.ContentLayerReady or {}
GamePlugin.Event.Draw = GamePlugin.Event.Draw or {}
GamePlugin.Event.EntityDraw = GamePlugin.Event.EntityDraw or {}
GamePlugin.Event.GameStateChanged = GamePlugin.Event.GameStateChanged or {}
GamePlugin.Event.GrandExchangeOfferUpdated = GamePlugin.Event.GrandExchangeOfferUpdated or {}
GamePlugin.Event.InventoryAdded = GamePlugin.Event.InventoryAdded or {}
GamePlugin.Event.InventoryRemoved = GamePlugin.Event.InventoryRemoved or {}
GamePlugin.Event.InventoryUpdated = GamePlugin.Event.InventoryUpdated or {}
GamePlugin.Event.KeyDown = GamePlugin.Event.KeyDown or {}
GamePlugin.Event.KeyTyped = GamePlugin.Event.KeyTyped or {}
GamePlugin.Event.KeyUp = GamePlugin.Event.KeyUp or {}
GamePlugin.Event.LocAdded = GamePlugin.Event.LocAdded or {}
GamePlugin.Event.LocAnimation = GamePlugin.Event.LocAnimation or {}
GamePlugin.Event.LocCustomised = GamePlugin.Event.LocCustomised or {}
GamePlugin.Event.LocRemoved = GamePlugin.Event.LocRemoved or {}
GamePlugin.Event.Logic = GamePlugin.Event.Logic or {}
GamePlugin.Event.MiniMenuClosed = GamePlugin.Event.MiniMenuClosed or {}
GamePlugin.Event.MiniMenuEntryAdded = GamePlugin.Event.MiniMenuEntryAdded or {}
GamePlugin.Event.MiniMenuEntrySelected = GamePlugin.Event.MiniMenuEntrySelected or {}
GamePlugin.Event.MiniMenuOpened = GamePlugin.Event.MiniMenuOpened or {}
GamePlugin.Event.MiniMenuReady = GamePlugin.Event.MiniMenuReady or {}
GamePlugin.Event.NPCEntityAdded = GamePlugin.Event.NPCEntityAdded or {}
GamePlugin.Event.NPCEntityRemoved = GamePlugin.Event.NPCEntityRemoved or {}
GamePlugin.Event.ObjStackEntityAdded = GamePlugin.Event.ObjStackEntityAdded or {}
GamePlugin.Event.ObjStackEntityChanged = GamePlugin.Event.ObjStackEntityChanged or {}
GamePlugin.Event.ObjStackEntityRemoved = GamePlugin.Event.ObjStackEntityRemoved or {}
GamePlugin.Event.OptionalDependencyChanged = GamePlugin.Event.OptionalDependencyChanged or {}
GamePlugin.Event.OptionalPermissionChanged = GamePlugin.Event.OptionalPermissionChanged or {}
GamePlugin.Event.PlayerEntityAdded = GamePlugin.Event.PlayerEntityAdded or {}
GamePlugin.Event.PlayerEntityRemoved = GamePlugin.Event.PlayerEntityRemoved or {}
GamePlugin.Event.RegionCreated = GamePlugin.Event.RegionCreated or {}
GamePlugin.Event.RegionUpdated = GamePlugin.Event.RegionUpdated or {}
GamePlugin.Event.RunEnergyTransmit = GamePlugin.Event.RunEnergyTransmit or {}
GamePlugin.Event.RunWeightTransmit = GamePlugin.Event.RunWeightTransmit or {}
GamePlugin.Event.ServerLogic = GamePlugin.Event.ServerLogic or {}
GamePlugin.Event.SettingsLayerReady = GamePlugin.Event.SettingsLayerReady or {}
GamePlugin.Event.SkillTransmit = GamePlugin.Event.SkillTransmit or {}
GamePlugin.Event.VarTransmit = GamePlugin.Event.VarTransmit or {}
GamePlugin.Event.WindowFocusChanged = GamePlugin.Event.WindowFocusChanged or {}
GamePlugin.Event.WindowSizeChanged = GamePlugin.Event.WindowSizeChanged or {}
GamePlugin.Event.WorldCreated = GamePlugin.Event.WorldCreated or {}
GamePlugin.Event.WorldUpdated = GamePlugin.Event.WorldUpdated or {}
GamePlugin.World.RemoveRoof = GamePlugin.World.RemoveRoof or {}
GamePlugin.audio.AudioBus = GamePlugin.audio.AudioBus or {}
GamePlugin.audio.EmitterShape = GamePlugin.audio.EmitterShape or {}
GamePlugin.audio.SoundType = GamePlugin.audio.SoundType or {}
GamePlugin.config.Achievement = GamePlugin.config.Achievement or {}
GamePlugin.config.BaseAnimSet = GamePlugin.config.BaseAnimSet or {}
GamePlugin.config.Cursor = GamePlugin.config.Cursor or {}
GamePlugin.config.DBRow = GamePlugin.config.DBRow or {}
GamePlugin.config.DBTable = GamePlugin.config.DBTable or {}
GamePlugin.config.Enum = GamePlugin.config.Enum or {}
GamePlugin.config.Font = GamePlugin.config.Font or {}
GamePlugin.config.Headbar = GamePlugin.config.Headbar or {}
GamePlugin.config.Hitmark = GamePlugin.config.Hitmark or {}
GamePlugin.config.Inv = GamePlugin.config.Inv or {}
GamePlugin.config.Loc = GamePlugin.config.Loc or {}
GamePlugin.config.MapElement = GamePlugin.config.MapElement or {}
GamePlugin.config.NPC = GamePlugin.config.NPC or {}
GamePlugin.config.Obj = GamePlugin.config.Obj or {}
GamePlugin.config.Param = GamePlugin.config.Param or {}
GamePlugin.config.Quest = GamePlugin.config.Quest or {}
GamePlugin.config.Seq = GamePlugin.config.Seq or {}
GamePlugin.config.Struct = GamePlugin.config.Struct or {}
GamePlugin.id.Achievement = GamePlugin.id.Achievement or {}
GamePlugin.id.BaseAnimSet = GamePlugin.id.BaseAnimSet or {}
GamePlugin.id.Category = GamePlugin.id.Category or {}
GamePlugin.id.Component = GamePlugin.id.Component or {}
GamePlugin.id.Cursor = GamePlugin.id.Cursor or {}
GamePlugin.id.DBRow = GamePlugin.id.DBRow or {}
GamePlugin.id.DBTable = GamePlugin.id.DBTable or {}
GamePlugin.id.Enum = GamePlugin.id.Enum or {}
GamePlugin.id.Font = GamePlugin.id.Font or {}
GamePlugin.id.Headbar = GamePlugin.id.Headbar or {}
GamePlugin.id.Hitmark = GamePlugin.id.Hitmark or {}
GamePlugin.id.Interface = GamePlugin.id.Interface or {}
GamePlugin.id.Inv = GamePlugin.id.Inv or {}
GamePlugin.id.Loc = GamePlugin.id.Loc or {}
GamePlugin.id.MapElement = GamePlugin.id.MapElement or {}
GamePlugin.id.Material = GamePlugin.id.Material or {}
GamePlugin.id.Model = GamePlugin.id.Model or {}
GamePlugin.id.Music = GamePlugin.id.Music or {}
GamePlugin.id.NPC = GamePlugin.id.NPC or {}
GamePlugin.id.Obj = GamePlugin.id.Obj or {}
GamePlugin.id.Param = GamePlugin.id.Param or {}
GamePlugin.id.Quest = GamePlugin.id.Quest or {}
GamePlugin.id.Seq = GamePlugin.id.Seq or {}
GamePlugin.id.Sound = GamePlugin.id.Sound or {}
GamePlugin.id.Sprite = GamePlugin.id.Sprite or {}
GamePlugin.id.Struct = GamePlugin.id.Struct or {}
GamePlugin.id.StyleSheet = GamePlugin.id.StyleSheet or {}
GamePlugin.id.UIAnim = GamePlugin.id.UIAnim or {}
GamePlugin.id.UIAnimCurve = GamePlugin.id.UIAnimCurve or {}
GamePlugin.id.VarClan = GamePlugin.id.VarClan or {}
GamePlugin.id.VarClanSetting = GamePlugin.id.VarClanSetting or {}
GamePlugin.id.VarClient = GamePlugin.id.VarClient or {}
GamePlugin.id.VarPlayer = GamePlugin.id.VarPlayer or {}
GamePlugin.id.VarPlayerGroup = GamePlugin.id.VarPlayerGroup or {}
GamePlugin.ui.AlignMode = GamePlugin.ui.AlignMode or {}
GamePlugin.ui.CarouselButtonDisplayMode = GamePlugin.ui.CarouselButtonDisplayMode or {}
GamePlugin.ui.CheckAlignMode = GamePlugin.ui.CheckAlignMode or {}
GamePlugin.ui.ComponentType = GamePlugin.ui.ComponentType or {}
GamePlugin.ui.DragRenderBehaviour = GamePlugin.ui.DragRenderBehaviour or {}
GamePlugin.ui.GroupBoxHeaderAlignMode = GamePlugin.ui.GroupBoxHeaderAlignMode or {}
GamePlugin.ui.InputFieldActionResult = GamePlugin.ui.InputFieldActionResult or {}
GamePlugin.ui.InputFieldFilterMode = GamePlugin.ui.InputFieldFilterMode or {}
GamePlugin.ui.InputFieldKeyHandlingMode = GamePlugin.ui.InputFieldKeyHandlingMode or {}
GamePlugin.ui.ModelCameraTransition = GamePlugin.ui.ModelCameraTransition or {}
GamePlugin.ui.ModelType = GamePlugin.ui.ModelType or {}
GamePlugin.ui.ObjectQuantityDisplayMode = GamePlugin.ui.ObjectQuantityDisplayMode or {}
GamePlugin.ui.PinchAxisBit = GamePlugin.ui.PinchAxisBit or {}
GamePlugin.ui.PlayerOpType = GamePlugin.ui.PlayerOpType or {}
GamePlugin.ui.RadialProgressOverlayFlag = GamePlugin.ui.RadialProgressOverlayFlag or {}
GamePlugin.ui.SwipeDirectionBit = GamePlugin.ui.SwipeDirectionBit or {}
GamePlugin.ui.TextContentVisibilityMode = GamePlugin.ui.TextContentVisibilityMode or {}
GamePlugin.ui.TriggerMode = GamePlugin.ui.TriggerMode or {}
GamePlugin.var.VarClan = GamePlugin.var.VarClan or {}
GamePlugin.var.VarClanSetting = GamePlugin.var.VarClanSetting or {}
GamePlugin.var.VarClient = GamePlugin.var.VarClient or {}
GamePlugin.var.VarPlayer = GamePlugin.var.VarPlayer or {}
GamePlugin.var.VarPlayerGroup = GamePlugin.var.VarPlayerGroup or {}
function GamePlugin.AchievementDescriptionType.FromID(...) return GamePlugin.CallExe("AchievementDescriptionType.FromID", ...) end
function GamePlugin.AchievementHiddenType.FromID(...) return GamePlugin.CallExe("AchievementHiddenType.FromID", ...) end
function GamePlugin.AchievementProgressType.FromID(...) return GamePlugin.CallExe("AchievementProgressType.FromID", ...) end
function GamePlugin.AnimationDuplicateBehaviour.FromID(...) return GamePlugin.CallExe("AnimationDuplicateBehaviour.FromID", ...) end
function GamePlugin.BoxCornerType.FromID(...) return GamePlugin.CallExe("BoxCornerType.FromID", ...) end
function GamePlugin.Camera.GetFocusPosition(...) return GamePlugin.CallExe("Camera.GetFocusPosition", ...) end
function GamePlugin.Camera.GetPosition(...) return GamePlugin.CallExe("Camera.GetPosition", ...) end
function GamePlugin.Camera.IsAvailable(...) return GamePlugin.CallExe("Camera.IsAvailable", ...) end
function GamePlugin.Chat.AddMessage(...) return GamePlugin.CallExe("Chat.AddMessage", ...) end
function GamePlugin.ChatType.FromID(...) return GamePlugin.CallExe("ChatType.FromID", ...) end
function GamePlugin.EntityType.FromID(...) return GamePlugin.CallExe("EntityType.FromID", ...) end
function GamePlugin.Event.ChatMessage.Subscribe(...) return GamePlugin.CallExe("Event.ChatMessage.Subscribe", ...) end
function GamePlugin.Event.ChatMessage.Unsubscribe(...) return GamePlugin.CallExe("Event.ChatMessage.Unsubscribe", ...) end
function GamePlugin.Event.ContentLayerReady.Subscribe(...) return GamePlugin.CallExe("Event.ContentLayerReady.Subscribe", ...) end
function GamePlugin.Event.ContentLayerReady.Unsubscribe(...) return GamePlugin.CallExe("Event.ContentLayerReady.Unsubscribe", ...) end
function GamePlugin.Event.Draw.Subscribe(...) return GamePlugin.CallExe("Event.Draw.Subscribe", ...) end
function GamePlugin.Event.Draw.Unsubscribe(...) return GamePlugin.CallExe("Event.Draw.Unsubscribe", ...) end
function GamePlugin.Event.EntityDraw.Subscribe(...) return GamePlugin.CallExe("Event.EntityDraw.Subscribe", ...) end
function GamePlugin.Event.EntityDraw.Unsubscribe(...) return GamePlugin.CallExe("Event.EntityDraw.Unsubscribe", ...) end
function GamePlugin.Event.GameStateChanged.Subscribe(...) return GamePlugin.CallExe("Event.GameStateChanged.Subscribe", ...) end
function GamePlugin.Event.GameStateChanged.Unsubscribe(...) return GamePlugin.CallExe("Event.GameStateChanged.Unsubscribe", ...) end
function GamePlugin.Event.GrandExchangeOfferUpdated.Subscribe(...) return GamePlugin.CallExe("Event.GrandExchangeOfferUpdated.Subscribe", ...) end
function GamePlugin.Event.GrandExchangeOfferUpdated.Unsubscribe(...) return GamePlugin.CallExe("Event.GrandExchangeOfferUpdated.Unsubscribe", ...) end
function GamePlugin.Event.InventoryAdded.Subscribe(...) return GamePlugin.CallExe("Event.InventoryAdded.Subscribe", ...) end
function GamePlugin.Event.InventoryAdded.Unsubscribe(...) return GamePlugin.CallExe("Event.InventoryAdded.Unsubscribe", ...) end
function GamePlugin.Event.InventoryRemoved.Subscribe(...) return GamePlugin.CallExe("Event.InventoryRemoved.Subscribe", ...) end
function GamePlugin.Event.InventoryRemoved.Unsubscribe(...) return GamePlugin.CallExe("Event.InventoryRemoved.Unsubscribe", ...) end
function GamePlugin.Event.InventoryUpdated.Subscribe(...) return GamePlugin.CallExe("Event.InventoryUpdated.Subscribe", ...) end
function GamePlugin.Event.InventoryUpdated.Unsubscribe(...) return GamePlugin.CallExe("Event.InventoryUpdated.Unsubscribe", ...) end
function GamePlugin.Event.KeyDown.Subscribe(...) return GamePlugin.CallExe("Event.KeyDown.Subscribe", ...) end
function GamePlugin.Event.KeyDown.Unsubscribe(...) return GamePlugin.CallExe("Event.KeyDown.Unsubscribe", ...) end
function GamePlugin.Event.KeyTyped.Subscribe(...) return GamePlugin.CallExe("Event.KeyTyped.Subscribe", ...) end
function GamePlugin.Event.KeyTyped.Unsubscribe(...) return GamePlugin.CallExe("Event.KeyTyped.Unsubscribe", ...) end
function GamePlugin.Event.KeyUp.Subscribe(...) return GamePlugin.CallExe("Event.KeyUp.Subscribe", ...) end
function GamePlugin.Event.KeyUp.Unsubscribe(...) return GamePlugin.CallExe("Event.KeyUp.Unsubscribe", ...) end
function GamePlugin.Event.LocAdded.Subscribe(...) return GamePlugin.CallExe("Event.LocAdded.Subscribe", ...) end
function GamePlugin.Event.LocAdded.Unsubscribe(...) return GamePlugin.CallExe("Event.LocAdded.Unsubscribe", ...) end
function GamePlugin.Event.LocAnimation.Subscribe(...) return GamePlugin.CallExe("Event.LocAnimation.Subscribe", ...) end
function GamePlugin.Event.LocAnimation.Unsubscribe(...) return GamePlugin.CallExe("Event.LocAnimation.Unsubscribe", ...) end
function GamePlugin.Event.LocCustomised.Subscribe(...) return GamePlugin.CallExe("Event.LocCustomised.Subscribe", ...) end
function GamePlugin.Event.LocCustomised.Unsubscribe(...) return GamePlugin.CallExe("Event.LocCustomised.Unsubscribe", ...) end
function GamePlugin.Event.LocRemoved.Subscribe(...) return GamePlugin.CallExe("Event.LocRemoved.Subscribe", ...) end
function GamePlugin.Event.LocRemoved.Unsubscribe(...) return GamePlugin.CallExe("Event.LocRemoved.Unsubscribe", ...) end
function GamePlugin.Event.Logic.Subscribe(...) return GamePlugin.CallExe("Event.Logic.Subscribe", ...) end
function GamePlugin.Event.Logic.Unsubscribe(...) return GamePlugin.CallExe("Event.Logic.Unsubscribe", ...) end
function GamePlugin.Event.MiniMenuClosed.Subscribe(...) return GamePlugin.CallExe("Event.MiniMenuClosed.Subscribe", ...) end
function GamePlugin.Event.MiniMenuClosed.Unsubscribe(...) return GamePlugin.CallExe("Event.MiniMenuClosed.Unsubscribe", ...) end
function GamePlugin.Event.MiniMenuEntryAdded.Subscribe(...) return GamePlugin.CallExe("Event.MiniMenuEntryAdded.Subscribe", ...) end
function GamePlugin.Event.MiniMenuEntryAdded.Unsubscribe(...) return GamePlugin.CallExe("Event.MiniMenuEntryAdded.Unsubscribe", ...) end
function GamePlugin.Event.MiniMenuEntrySelected.Subscribe(...) return GamePlugin.CallExe("Event.MiniMenuEntrySelected.Subscribe", ...) end
function GamePlugin.Event.MiniMenuEntrySelected.Unsubscribe(...) return GamePlugin.CallExe("Event.MiniMenuEntrySelected.Unsubscribe", ...) end
function GamePlugin.Event.MiniMenuOpened.Subscribe(...) return GamePlugin.CallExe("Event.MiniMenuOpened.Subscribe", ...) end
function GamePlugin.Event.MiniMenuOpened.Unsubscribe(...) return GamePlugin.CallExe("Event.MiniMenuOpened.Unsubscribe", ...) end
function GamePlugin.Event.MiniMenuReady.Subscribe(...) return GamePlugin.CallExe("Event.MiniMenuReady.Subscribe", ...) end
function GamePlugin.Event.MiniMenuReady.Unsubscribe(...) return GamePlugin.CallExe("Event.MiniMenuReady.Unsubscribe", ...) end
function GamePlugin.Event.NPCEntityAdded.Subscribe(...) return GamePlugin.CallExe("Event.NPCEntityAdded.Subscribe", ...) end
function GamePlugin.Event.NPCEntityAdded.Unsubscribe(...) return GamePlugin.CallExe("Event.NPCEntityAdded.Unsubscribe", ...) end
function GamePlugin.Event.NPCEntityRemoved.Subscribe(...) return GamePlugin.CallExe("Event.NPCEntityRemoved.Subscribe", ...) end
function GamePlugin.Event.NPCEntityRemoved.Unsubscribe(...) return GamePlugin.CallExe("Event.NPCEntityRemoved.Unsubscribe", ...) end
function GamePlugin.Event.ObjStackEntityAdded.Subscribe(...) return GamePlugin.CallExe("Event.ObjStackEntityAdded.Subscribe", ...) end
function GamePlugin.Event.ObjStackEntityAdded.Unsubscribe(...) return GamePlugin.CallExe("Event.ObjStackEntityAdded.Unsubscribe", ...) end
function GamePlugin.Event.ObjStackEntityChanged.Subscribe(...) return GamePlugin.CallExe("Event.ObjStackEntityChanged.Subscribe", ...) end
function GamePlugin.Event.ObjStackEntityChanged.Unsubscribe(...) return GamePlugin.CallExe("Event.ObjStackEntityChanged.Unsubscribe", ...) end
function GamePlugin.Event.ObjStackEntityRemoved.Subscribe(...) return GamePlugin.CallExe("Event.ObjStackEntityRemoved.Subscribe", ...) end
function GamePlugin.Event.ObjStackEntityRemoved.Unsubscribe(...) return GamePlugin.CallExe("Event.ObjStackEntityRemoved.Unsubscribe", ...) end
function GamePlugin.Event.OptionalDependencyChanged.Subscribe(...) return GamePlugin.CallExe("Event.OptionalDependencyChanged.Subscribe", ...) end
function GamePlugin.Event.OptionalDependencyChanged.Unsubscribe(...) return GamePlugin.CallExe("Event.OptionalDependencyChanged.Unsubscribe", ...) end
function GamePlugin.Event.OptionalPermissionChanged.Subscribe(...) return GamePlugin.CallExe("Event.OptionalPermissionChanged.Subscribe", ...) end
function GamePlugin.Event.OptionalPermissionChanged.Unsubscribe(...) return GamePlugin.CallExe("Event.OptionalPermissionChanged.Unsubscribe", ...) end
function GamePlugin.Event.PlayerEntityAdded.Subscribe(...) return GamePlugin.CallExe("Event.PlayerEntityAdded.Subscribe", ...) end
function GamePlugin.Event.PlayerEntityAdded.Unsubscribe(...) return GamePlugin.CallExe("Event.PlayerEntityAdded.Unsubscribe", ...) end
function GamePlugin.Event.PlayerEntityRemoved.Subscribe(...) return GamePlugin.CallExe("Event.PlayerEntityRemoved.Subscribe", ...) end
function GamePlugin.Event.PlayerEntityRemoved.Unsubscribe(...) return GamePlugin.CallExe("Event.PlayerEntityRemoved.Unsubscribe", ...) end
function GamePlugin.Event.RegionCreated.Subscribe(...) return GamePlugin.CallExe("Event.RegionCreated.Subscribe", ...) end
function GamePlugin.Event.RegionCreated.Unsubscribe(...) return GamePlugin.CallExe("Event.RegionCreated.Unsubscribe", ...) end
function GamePlugin.Event.RegionUpdated.Subscribe(...) return GamePlugin.CallExe("Event.RegionUpdated.Subscribe", ...) end
function GamePlugin.Event.RegionUpdated.Unsubscribe(...) return GamePlugin.CallExe("Event.RegionUpdated.Unsubscribe", ...) end
function GamePlugin.Event.RunEnergyTransmit.Subscribe(...) return GamePlugin.CallExe("Event.RunEnergyTransmit.Subscribe", ...) end
function GamePlugin.Event.RunEnergyTransmit.Unsubscribe(...) return GamePlugin.CallExe("Event.RunEnergyTransmit.Unsubscribe", ...) end
function GamePlugin.Event.RunWeightTransmit.Subscribe(...) return GamePlugin.CallExe("Event.RunWeightTransmit.Subscribe", ...) end
function GamePlugin.Event.RunWeightTransmit.Unsubscribe(...) return GamePlugin.CallExe("Event.RunWeightTransmit.Unsubscribe", ...) end
function GamePlugin.Event.ServerLogic.Subscribe(...) return GamePlugin.CallExe("Event.ServerLogic.Subscribe", ...) end
function GamePlugin.Event.ServerLogic.Unsubscribe(...) return GamePlugin.CallExe("Event.ServerLogic.Unsubscribe", ...) end
function GamePlugin.Event.SettingsLayerReady.Subscribe(...) return GamePlugin.CallExe("Event.SettingsLayerReady.Subscribe", ...) end
function GamePlugin.Event.SettingsLayerReady.Unsubscribe(...) return GamePlugin.CallExe("Event.SettingsLayerReady.Unsubscribe", ...) end
function GamePlugin.Event.SkillTransmit.Subscribe(...) return GamePlugin.CallExe("Event.SkillTransmit.Subscribe", ...) end
function GamePlugin.Event.SkillTransmit.Unsubscribe(...) return GamePlugin.CallExe("Event.SkillTransmit.Unsubscribe", ...) end
function GamePlugin.Event.VarTransmit.Subscribe(...) return GamePlugin.CallExe("Event.VarTransmit.Subscribe", ...) end
function GamePlugin.Event.VarTransmit.Unsubscribe(...) return GamePlugin.CallExe("Event.VarTransmit.Unsubscribe", ...) end
function GamePlugin.Event.WindowFocusChanged.Subscribe(...) return GamePlugin.CallExe("Event.WindowFocusChanged.Subscribe", ...) end
function GamePlugin.Event.WindowFocusChanged.Unsubscribe(...) return GamePlugin.CallExe("Event.WindowFocusChanged.Unsubscribe", ...) end
function GamePlugin.Event.WindowSizeChanged.Subscribe(...) return GamePlugin.CallExe("Event.WindowSizeChanged.Subscribe", ...) end
function GamePlugin.Event.WindowSizeChanged.Unsubscribe(...) return GamePlugin.CallExe("Event.WindowSizeChanged.Unsubscribe", ...) end
function GamePlugin.Event.WorldCreated.Subscribe(...) return GamePlugin.CallExe("Event.WorldCreated.Subscribe", ...) end
function GamePlugin.Event.WorldCreated.Unsubscribe(...) return GamePlugin.CallExe("Event.WorldCreated.Unsubscribe", ...) end
function GamePlugin.Event.WorldUpdated.Subscribe(...) return GamePlugin.CallExe("Event.WorldUpdated.Subscribe", ...) end
function GamePlugin.Event.WorldUpdated.Unsubscribe(...) return GamePlugin.CallExe("Event.WorldUpdated.Unsubscribe", ...) end
function GamePlugin.GameKey.FromID(...) return GamePlugin.CallExe("GameKey.FromID", ...) end
function GamePlugin.GameState.FromID(...) return GamePlugin.CallExe("GameState.FromID", ...) end
function GamePlugin.GrandExchange.GetOffer(...) return GamePlugin.CallExe("GrandExchange.GetOffer", ...) end
function GamePlugin.GrandExchange.MaxOffers(...) return GamePlugin.CallExe("GrandExchange.MaxOffers", ...) end
function GamePlugin.GrandExchangeOfferStage.FromID(...) return GamePlugin.CallExe("GrandExchangeOfferStage.FromID", ...) end
function GamePlugin.GrandExchangeOfferType.FromID(...) return GamePlugin.CallExe("GrandExchangeOfferType.FromID", ...) end
function GamePlugin.HeightOffsetType.FromID(...) return GamePlugin.CallExe("HeightOffsetType.FromID", ...) end
function GamePlugin.HintList.AddArrow(...) return GamePlugin.CallExe("HintList.AddArrow", ...) end
function GamePlugin.HintList.AddPolygon(...) return GamePlugin.CallExe("HintList.AddPolygon", ...) end
function GamePlugin.HintList.AddTrail(...) return GamePlugin.CallExe("HintList.AddTrail", ...) end
function GamePlugin.HintList.HasArrow(...) return GamePlugin.CallExe("HintList.HasArrow", ...) end
function GamePlugin.HintList.HasPolygon(...) return GamePlugin.CallExe("HintList.HasPolygon", ...) end
function GamePlugin.HintList.HasTrail(...) return GamePlugin.CallExe("HintList.HasTrail", ...) end
function GamePlugin.HintList.RemoveArrow(...) return GamePlugin.CallExe("HintList.RemoveArrow", ...) end
function GamePlugin.HintList.RemovePolygon(...) return GamePlugin.CallExe("HintList.RemovePolygon", ...) end
function GamePlugin.HintList.RemoveTrail(...) return GamePlugin.CallExe("HintList.RemoveTrail", ...) end
function GamePlugin.Inventory.Find(...) return GamePlugin.CallExe("Inventory.Find", ...) end
function GamePlugin.Keyboard.GetGameKeysDown(...) return GamePlugin.CallExe("Keyboard.GetGameKeysDown", ...) end
function GamePlugin.Keyboard.IsAltDown(...) return GamePlugin.CallExe("Keyboard.IsAltDown", ...) end
function GamePlugin.Keyboard.IsAvailable(...) return GamePlugin.CallExe("Keyboard.IsAvailable", ...) end
function GamePlugin.Keyboard.IsBlocked(...) return GamePlugin.CallExe("Keyboard.IsBlocked", ...) end
function GamePlugin.Keyboard.IsControlDown(...) return GamePlugin.CallExe("Keyboard.IsControlDown", ...) end
function GamePlugin.Keyboard.IsGameKeyDown(...) return GamePlugin.CallExe("Keyboard.IsGameKeyDown", ...) end
function GamePlugin.Keyboard.IsMetaDown(...) return GamePlugin.CallExe("Keyboard.IsMetaDown", ...) end
function GamePlugin.Keyboard.IsShiftDown(...) return GamePlugin.CallExe("Keyboard.IsShiftDown", ...) end
function GamePlugin.LocList.All(...) return GamePlugin.CallExe("LocList.All", ...) end
function GamePlugin.LocList.ByConfig(...) return GamePlugin.CallExe("LocList.ByConfig", ...) end
function GamePlugin.LocList.ByConfigID(...) return GamePlugin.CallExe("LocList.ByConfigID", ...) end
function GamePlugin.LocList.ByDistance(...) return GamePlugin.CallExe("LocList.ByDistance", ...) end
function GamePlugin.LocList.ByName(...) return GamePlugin.CallExe("LocList.ByName", ...) end
function GamePlugin.LocList.ByParentConfig(...) return GamePlugin.CallExe("LocList.ByParentConfig", ...) end
function GamePlugin.LocList.ByParentConfigID(...) return GamePlugin.CallExe("LocList.ByParentConfigID", ...) end
function GamePlugin.LocList.Filter(...) return GamePlugin.CallExe("LocList.Filter", ...) end
function GamePlugin.LocShapeType.FromID(...) return GamePlugin.CallExe("LocShapeType.FromID", ...) end
function GamePlugin.MapElementHorizontalAlign.FromID(...) return GamePlugin.CallExe("MapElementHorizontalAlign.FromID", ...) end
function GamePlugin.MapElementTextSize.FromID(...) return GamePlugin.CallExe("MapElementTextSize.FromID", ...) end
function GamePlugin.MapElementVerticalAlign.FromID(...) return GamePlugin.CallExe("MapElementVerticalAlign.FromID", ...) end
function GamePlugin.MiniMenu.IsOpen(...) return GamePlugin.CallExe("MiniMenu.IsOpen", ...) end
function GamePlugin.MiniMenuActionType.FromID(...) return GamePlugin.CallExe("MiniMenuActionType.FromID", ...) end
function GamePlugin.MiniMenuActionVerbType.FromID(...) return GamePlugin.CallExe("MiniMenuActionVerbType.FromID", ...) end
function GamePlugin.MiniMenuEntryType.FromID(...) return GamePlugin.CallExe("MiniMenuEntryType.FromID", ...) end
function GamePlugin.ModifierKey.FromID(...) return GamePlugin.CallExe("ModifierKey.FromID", ...) end
function GamePlugin.Mouse.GetPosition(...) return GamePlugin.CallExe("Mouse.GetPosition", ...) end
function GamePlugin.Mouse.GetX(...) return GamePlugin.CallExe("Mouse.GetX", ...) end
function GamePlugin.Mouse.GetY(...) return GamePlugin.CallExe("Mouse.GetY", ...) end
function GamePlugin.Mouse.IsAvailable(...) return GamePlugin.CallExe("Mouse.IsAvailable", ...) end
function GamePlugin.NPCList.All(...) return GamePlugin.CallExe("NPCList.All", ...) end
function GamePlugin.NPCList.ByConfig(...) return GamePlugin.CallExe("NPCList.ByConfig", ...) end
function GamePlugin.NPCList.ByConfigID(...) return GamePlugin.CallExe("NPCList.ByConfigID", ...) end
function GamePlugin.NPCList.ByDistance(...) return GamePlugin.CallExe("NPCList.ByDistance", ...) end
function GamePlugin.NPCList.ByName(...) return GamePlugin.CallExe("NPCList.ByName", ...) end
function GamePlugin.NPCList.ByParentConfig(...) return GamePlugin.CallExe("NPCList.ByParentConfig", ...) end
function GamePlugin.NPCList.ByParentConfigID(...) return GamePlugin.CallExe("NPCList.ByParentConfigID", ...) end
function GamePlugin.NPCList.ByUID(...) return GamePlugin.CallExe("NPCList.ByUID", ...) end
function GamePlugin.NPCList.Filter(...) return GamePlugin.CallExe("NPCList.Filter", ...) end
function GamePlugin.ObjStackList.All(...) return GamePlugin.CallExe("ObjStackList.All", ...) end
function GamePlugin.ObjStackList.ByConfig(...) return GamePlugin.CallExe("ObjStackList.ByConfig", ...) end
function GamePlugin.ObjStackList.ByConfigID(...) return GamePlugin.CallExe("ObjStackList.ByConfigID", ...) end
function GamePlugin.ObjStackList.ByDistance(...) return GamePlugin.CallExe("ObjStackList.ByDistance", ...) end
function GamePlugin.ObjStackList.ByName(...) return GamePlugin.CallExe("ObjStackList.ByName", ...) end
function GamePlugin.ObjStackList.Filter(...) return GamePlugin.CallExe("ObjStackList.Filter", ...) end
function GamePlugin.ObjStackType.FromID(...) return GamePlugin.CallExe("ObjStackType.FromID", ...) end
function GamePlugin.Player.GetCombatLevel(...) return GamePlugin.CallExe("Player.GetCombatLevel", ...) end
function GamePlugin.Player.GetEntity(...) return GamePlugin.CallExe("Player.GetEntity", ...) end
function GamePlugin.Player.GetLevelCapped(...) return GamePlugin.CallExe("Player.GetLevelCapped", ...) end
function GamePlugin.Player.GetLevelGameplay(...) return GamePlugin.CallExe("Player.GetLevelGameplay", ...) end
function GamePlugin.Player.GetLevelUncapped(...) return GamePlugin.CallExe("Player.GetLevelUncapped", ...) end
function GamePlugin.Player.GetRunEnergy(...) return GamePlugin.CallExe("Player.GetRunEnergy", ...) end
function GamePlugin.Player.GetTrackingID(...) return GamePlugin.CallExe("Player.GetTrackingID", ...) end
function GamePlugin.Player.GetWeight(...) return GamePlugin.CallExe("Player.GetWeight", ...) end
function GamePlugin.Player.GetXPCapped(...) return GamePlugin.CallExe("Player.GetXPCapped", ...) end
function GamePlugin.Player.GetXPUncapped(...) return GamePlugin.CallExe("Player.GetXPUncapped", ...) end
function GamePlugin.Player.IsAvailable(...) return GamePlugin.CallExe("Player.IsAvailable", ...) end
function GamePlugin.PlayerList.All(...) return GamePlugin.CallExe("PlayerList.All", ...) end
function GamePlugin.PlayerList.ByDistance(...) return GamePlugin.CallExe("PlayerList.ByDistance", ...) end
function GamePlugin.PlayerList.ByName(...) return GamePlugin.CallExe("PlayerList.ByName", ...) end
function GamePlugin.PlayerList.ByUID(...) return GamePlugin.CallExe("PlayerList.ByUID", ...) end
function GamePlugin.PlayerList.Filter(...) return GamePlugin.CallExe("PlayerList.Filter", ...) end
function GamePlugin.PlayerList.Self(...) return GamePlugin.CallExe("PlayerList.Self", ...) end
function GamePlugin.PluginResourceLoadResult.FromID(...) return GamePlugin.CallExe("PluginResourceLoadResult.FromID", ...) end
function GamePlugin.PostAnimMove.FromID(...) return GamePlugin.CallExe("PostAnimMove.FromID", ...) end
function GamePlugin.PreAnimMove.FromID(...) return GamePlugin.CallExe("PreAnimMove.FromID", ...) end
function GamePlugin.QuestDifficulty.FromID(...) return GamePlugin.CallExe("QuestDifficulty.FromID", ...) end
function GamePlugin.QuestType.FromID(...) return GamePlugin.CallExe("QuestType.FromID", ...) end
function GamePlugin.RotationType.FromID(...) return GamePlugin.CallExe("RotationType.FromID", ...) end
function GamePlugin.ScreenConvert.CoordFineToScreen(...) return GamePlugin.CallExe("ScreenConvert.CoordFineToScreen", ...) end
function GamePlugin.ScreenConvert.CoordGridToScreen(...) return GamePlugin.CallExe("ScreenConvert.CoordGridToScreen", ...) end
function GamePlugin.ScreenConvert.ScreenToCoordFine(...) return GamePlugin.CallExe("ScreenConvert.ScreenToCoordFine", ...) end
function GamePlugin.ScreenConvert.ScreenToCoordGrid(...) return GamePlugin.CallExe("ScreenConvert.ScreenToCoordGrid", ...) end
function GamePlugin.ScreenConvert.Vector3ToScreen(...) return GamePlugin.CallExe("ScreenConvert.Vector3ToScreen", ...) end
function GamePlugin.ShapeList.CreateEntity(...) return GamePlugin.CallExe("ShapeList.CreateEntity", ...) end
function GamePlugin.ShapeList.CreateInstance(...) return GamePlugin.CallExe("ShapeList.CreateInstance", ...) end
function GamePlugin.ShapeList.DestroyEntity(...) return GamePlugin.CallExe("ShapeList.DestroyEntity", ...) end
function GamePlugin.ShapeList.DestroyInstance(...) return GamePlugin.CallExe("ShapeList.DestroyInstance", ...) end
function GamePlugin.ShapeList.Draw(...) return GamePlugin.CallExe("ShapeList.Draw", ...) end
function GamePlugin.ShapeList.DrawLine(...) return GamePlugin.CallExe("ShapeList.DrawLine", ...) end
function GamePlugin.ShapeList.GetAllEntities(...) return GamePlugin.CallExe("ShapeList.GetAllEntities", ...) end
function GamePlugin.ShapeList.GetAllInstances(...) return GamePlugin.CallExe("ShapeList.GetAllInstances", ...) end
function GamePlugin.ShapeList.GetEntity(...) return GamePlugin.CallExe("ShapeList.GetEntity", ...) end
function GamePlugin.ShapeList.GetInstance(...) return GamePlugin.CallExe("ShapeList.GetInstance", ...) end
function GamePlugin.SkillType.FromID(...) return GamePlugin.CallExe("SkillType.FromID", ...) end
function GamePlugin.SystemKey.FromID(...) return GamePlugin.CallExe("SystemKey.FromID", ...) end
function GamePlugin.ValueType.FromID(...) return GamePlugin.CallExe("ValueType.FromID", ...) end
function GamePlugin.World.GetGroundHeight(...) return GamePlugin.CallExe("World.GetGroundHeight", ...) end
function GamePlugin.World.GetMapSquareBounds(...) return GamePlugin.CallExe("World.GetMapSquareBounds", ...) end
function GamePlugin.World.GetPing(...) return GamePlugin.CallExe("World.GetPing", ...) end
function GamePlugin.World.GetRebootTimer(...) return GamePlugin.CallExe("World.GetRebootTimer", ...) end
function GamePlugin.World.GetRegionSourceForCoordGrid(...) return GamePlugin.CallExe("World.GetRegionSourceForCoordGrid", ...) end
function GamePlugin.World.IsAvailable(...) return GamePlugin.CallExe("World.IsAvailable", ...) end
function GamePlugin.World.IsMembers(...) return GamePlugin.CallExe("World.IsMembers", ...) end
function GamePlugin.World.IsRegion(...) return GamePlugin.CallExe("World.IsRegion", ...) end
function GamePlugin.World.RemoveRoof.Add(...) return GamePlugin.CallExe("World.RemoveRoof.Add", ...) end
function GamePlugin.World.RemoveRoof.Clear(...) return GamePlugin.CallExe("World.RemoveRoof.Clear", ...) end
function GamePlugin.World.RemoveRoof.Remove(...) return GamePlugin.CallExe("World.RemoveRoof.Remove", ...) end
function GamePlugin.assert(...) return GamePlugin.CallExe("assert", ...) end
function GamePlugin.audio.AudioBus.FromID(...) return GamePlugin.CallExe("audio.AudioBus.FromID", ...) end
function GamePlugin.audio.EmitterShape.FromID(...) return GamePlugin.CallExe("audio.EmitterShape.FromID", ...) end
function GamePlugin.audio.Play(...) return GamePlugin.CallExe("audio.Play", ...) end
function GamePlugin.audio.SoundType.FromID(...) return GamePlugin.CallExe("audio.SoundType.FromID", ...) end
function GamePlugin.audio.Stop(...) return GamePlugin.CallExe("audio.Stop", ...) end
function GamePlugin.audio.StopSoundsUsingResource(...) return GamePlugin.CallExe("audio.StopSoundsUsingResource", ...) end
function GamePlugin.clamp(...) return GamePlugin.CallExe("clamp", ...) end
function GamePlugin.collectgarbage(...) return GamePlugin.CallExe("collectgarbage", ...) end
function GamePlugin.config.Achievement.FromID(...) return GamePlugin.CallExe("config.Achievement.FromID", ...) end
function GamePlugin.config.BaseAnimSet.FromID(...) return GamePlugin.CallExe("config.BaseAnimSet.FromID", ...) end
function GamePlugin.config.Cursor.FromID(...) return GamePlugin.CallExe("config.Cursor.FromID", ...) end
function GamePlugin.config.DBRow.FromID(...) return GamePlugin.CallExe("config.DBRow.FromID", ...) end
function GamePlugin.config.DBTable.FromID(...) return GamePlugin.CallExe("config.DBTable.FromID", ...) end
function GamePlugin.config.Enum.FromID(...) return GamePlugin.CallExe("config.Enum.FromID", ...) end
function GamePlugin.config.Font.FromID(...) return GamePlugin.CallExe("config.Font.FromID", ...) end
function GamePlugin.config.Headbar.FromID(...) return GamePlugin.CallExe("config.Headbar.FromID", ...) end
function GamePlugin.config.Hitmark.FromID(...) return GamePlugin.CallExe("config.Hitmark.FromID", ...) end
function GamePlugin.config.Inv.FromID(...) return GamePlugin.CallExe("config.Inv.FromID", ...) end
function GamePlugin.config.Loc.FromID(...) return GamePlugin.CallExe("config.Loc.FromID", ...) end
function GamePlugin.config.MapElement.FromID(...) return GamePlugin.CallExe("config.MapElement.FromID", ...) end
function GamePlugin.config.NPC.FromID(...) return GamePlugin.CallExe("config.NPC.FromID", ...) end
function GamePlugin.config.Obj.FromID(...) return GamePlugin.CallExe("config.Obj.FromID", ...) end
function GamePlugin.config.Param.FromID(...) return GamePlugin.CallExe("config.Param.FromID", ...) end
function GamePlugin.config.Quest.FromID(...) return GamePlugin.CallExe("config.Quest.FromID", ...) end
function GamePlugin.config.Seq.FromID(...) return GamePlugin.CallExe("config.Seq.FromID", ...) end
function GamePlugin.config.Struct.FromID(...) return GamePlugin.CallExe("config.Struct.FromID", ...) end
function GamePlugin.error(...) return GamePlugin.CallExe("error", ...) end
function GamePlugin.formatStr(...) return GamePlugin.CallExe("formatStr", ...) end
function GamePlugin.getmetatable(...) return GamePlugin.CallExe("getmetatable", ...) end
function GamePlugin.id.Achievement.FromID(...) return GamePlugin.CallExe("id.Achievement.FromID", ...) end
function GamePlugin.id.BaseAnimSet.FromID(...) return GamePlugin.CallExe("id.BaseAnimSet.FromID", ...) end
function GamePlugin.id.Category.FromID(...) return GamePlugin.CallExe("id.Category.FromID", ...) end
function GamePlugin.id.Component.FromID(...) return GamePlugin.CallExe("id.Component.FromID", ...) end
function GamePlugin.id.Cursor.FromID(...) return GamePlugin.CallExe("id.Cursor.FromID", ...) end
function GamePlugin.id.DBRow.FromID(...) return GamePlugin.CallExe("id.DBRow.FromID", ...) end
function GamePlugin.id.DBTable.FromID(...) return GamePlugin.CallExe("id.DBTable.FromID", ...) end
function GamePlugin.id.Enum.FromID(...) return GamePlugin.CallExe("id.Enum.FromID", ...) end
function GamePlugin.id.Font.FromID(...) return GamePlugin.CallExe("id.Font.FromID", ...) end
function GamePlugin.id.Headbar.FromID(...) return GamePlugin.CallExe("id.Headbar.FromID", ...) end
function GamePlugin.id.Hitmark.FromID(...) return GamePlugin.CallExe("id.Hitmark.FromID", ...) end
function GamePlugin.id.Interface.FromID(...) return GamePlugin.CallExe("id.Interface.FromID", ...) end
function GamePlugin.id.Inv.FromID(...) return GamePlugin.CallExe("id.Inv.FromID", ...) end
function GamePlugin.id.Loc.FromID(...) return GamePlugin.CallExe("id.Loc.FromID", ...) end
function GamePlugin.id.MapElement.FromID(...) return GamePlugin.CallExe("id.MapElement.FromID", ...) end
function GamePlugin.id.Material.FromID(...) return GamePlugin.CallExe("id.Material.FromID", ...) end
function GamePlugin.id.Model.FromID(...) return GamePlugin.CallExe("id.Model.FromID", ...) end
function GamePlugin.id.Music.FromID(...) return GamePlugin.CallExe("id.Music.FromID", ...) end
function GamePlugin.id.NPC.FromID(...) return GamePlugin.CallExe("id.NPC.FromID", ...) end
function GamePlugin.id.Obj.FromID(...) return GamePlugin.CallExe("id.Obj.FromID", ...) end
function GamePlugin.id.Param.FromID(...) return GamePlugin.CallExe("id.Param.FromID", ...) end
function GamePlugin.id.Quest.FromID(...) return GamePlugin.CallExe("id.Quest.FromID", ...) end
function GamePlugin.id.Seq.FromID(...) return GamePlugin.CallExe("id.Seq.FromID", ...) end
function GamePlugin.id.Sound.FromID(...) return GamePlugin.CallExe("id.Sound.FromID", ...) end
function GamePlugin.id.Sprite.FromID(...) return GamePlugin.CallExe("id.Sprite.FromID", ...) end
function GamePlugin.id.Struct.FromID(...) return GamePlugin.CallExe("id.Struct.FromID", ...) end
function GamePlugin.id.StyleSheet.FromID(...) return GamePlugin.CallExe("id.StyleSheet.FromID", ...) end
function GamePlugin.id.UIAnim.FromID(...) return GamePlugin.CallExe("id.UIAnim.FromID", ...) end
function GamePlugin.id.UIAnimCurve.FromID(...) return GamePlugin.CallExe("id.UIAnimCurve.FromID", ...) end
function GamePlugin.id.VarClan.FromID(...) return GamePlugin.CallExe("id.VarClan.FromID", ...) end
function GamePlugin.id.VarClanSetting.FromID(...) return GamePlugin.CallExe("id.VarClanSetting.FromID", ...) end
function GamePlugin.id.VarClient.FromID(...) return GamePlugin.CallExe("id.VarClient.FromID", ...) end
function GamePlugin.id.VarPlayer.FromID(...) return GamePlugin.CallExe("id.VarPlayer.FromID", ...) end
function GamePlugin.id.VarPlayerGroup.FromID(...) return GamePlugin.CallExe("id.VarPlayerGroup.FromID", ...) end
function GamePlugin.ipairs(...) return GamePlugin.CallExe("ipairs", ...) end
function GamePlugin.lerp(...) return GamePlugin.CallExe("lerp", ...) end
function GamePlugin.load(...) return GamePlugin.CallExe("load", ...) end
function GamePlugin.log(...) return GamePlugin.CallExe("log", ...) end
function GamePlugin.next(...) return GamePlugin.CallExe("next", ...) end
function GamePlugin.pairs(...) return GamePlugin.CallExe("pairs", ...) end
function GamePlugin.pcall(...) return GamePlugin.CallExe("pcall", ...) end
function GamePlugin.print(...) return GamePlugin.CallExe("print", ...) end
function GamePlugin.random(...) return GamePlugin.CallExe("random", ...) end
function GamePlugin.rawequal(...) return GamePlugin.CallExe("rawequal", ...) end
function GamePlugin.rawget(...) return GamePlugin.CallExe("rawget", ...) end
function GamePlugin.rawlen(...) return GamePlugin.CallExe("rawlen", ...) end
function GamePlugin.rawset(...) return GamePlugin.CallExe("rawset", ...) end
function GamePlugin.select(...) return GamePlugin.CallExe("select", ...) end
function GamePlugin.setmetatable(...) return GamePlugin.CallExe("setmetatable", ...) end
function GamePlugin.slerp(...) return GamePlugin.CallExe("slerp", ...) end
function GamePlugin.tonumber(...) return GamePlugin.CallExe("tonumber", ...) end
function GamePlugin.tostring(...) return GamePlugin.CallExe("tostring", ...) end
function GamePlugin.type(...) return GamePlugin.CallExe("type", ...) end
function GamePlugin.ui.AlignMode.FromID(...) return GamePlugin.CallExe("ui.AlignMode.FromID", ...) end
function GamePlugin.ui.CarouselButtonDisplayMode.FromID(...) return GamePlugin.CallExe("ui.CarouselButtonDisplayMode.FromID", ...) end
function GamePlugin.ui.CheckAlignMode.FromID(...) return GamePlugin.CallExe("ui.CheckAlignMode.FromID", ...) end
function GamePlugin.ui.CombinedID(...) return GamePlugin.CallExe("ui.CombinedID", ...) end
function GamePlugin.ui.ComponentType.FromID(...) return GamePlugin.CallExe("ui.ComponentType.FromID", ...) end
function GamePlugin.ui.DragRenderBehaviour.FromID(...) return GamePlugin.CallExe("ui.DragRenderBehaviour.FromID", ...) end
function GamePlugin.ui.GroupBoxHeaderAlignMode.FromID(...) return GamePlugin.CallExe("ui.GroupBoxHeaderAlignMode.FromID", ...) end
function GamePlugin.ui.InputFieldActionResult.FromID(...) return GamePlugin.CallExe("ui.InputFieldActionResult.FromID", ...) end
function GamePlugin.ui.InputFieldFilterMode.FromID(...) return GamePlugin.CallExe("ui.InputFieldFilterMode.FromID", ...) end
function GamePlugin.ui.InputFieldKeyHandlingMode.FromID(...) return GamePlugin.CallExe("ui.InputFieldKeyHandlingMode.FromID", ...) end
function GamePlugin.ui.ModelCameraTransition.FromID(...) return GamePlugin.CallExe("ui.ModelCameraTransition.FromID", ...) end
function GamePlugin.ui.ModelType.FromID(...) return GamePlugin.CallExe("ui.ModelType.FromID", ...) end
function GamePlugin.ui.ObjectQuantityDisplayMode.FromID(...) return GamePlugin.CallExe("ui.ObjectQuantityDisplayMode.FromID", ...) end
function GamePlugin.ui.PinchAxisBit.FromID(...) return GamePlugin.CallExe("ui.PinchAxisBit.FromID", ...) end
function GamePlugin.ui.PlayerOpType.FromID(...) return GamePlugin.CallExe("ui.PlayerOpType.FromID", ...) end
function GamePlugin.ui.RadialProgressOverlayFlag.FromID(...) return GamePlugin.CallExe("ui.RadialProgressOverlayFlag.FromID", ...) end
function GamePlugin.ui.SwipeDirectionBit.FromID(...) return GamePlugin.CallExe("ui.SwipeDirectionBit.FromID", ...) end
function GamePlugin.ui.TextContentVisibilityMode.FromID(...) return GamePlugin.CallExe("ui.TextContentVisibilityMode.FromID", ...) end
function GamePlugin.ui.TriggerMode.FromID(...) return GamePlugin.CallExe("ui.TriggerMode.FromID", ...) end
function GamePlugin.utils.CalcTextWidth(...) return GamePlugin.CallExe("utils.CalcTextWidth", ...) end
function GamePlugin.var.VarClan.FromID(...) return GamePlugin.CallExe("var.VarClan.FromID", ...) end
function GamePlugin.var.VarClanSetting.FromID(...) return GamePlugin.CallExe("var.VarClanSetting.FromID", ...) end
function GamePlugin.var.VarClient.FromID(...) return GamePlugin.CallExe("var.VarClient.FromID", ...) end
function GamePlugin.var.VarPlayer.FromID(...) return GamePlugin.CallExe("var.VarPlayer.FromID", ...) end
function GamePlugin.var.VarPlayerGroup.FromID(...) return GamePlugin.CallExe("var.VarPlayerGroup.FromID", ...) end
function GamePlugin.warn(...) return GamePlugin.CallExe("warn", ...) end
function GamePlugin.xpcall(...) return GamePlugin.CallExe("xpcall", ...) end

local function __gameplugin_bind(tbl, prefix)
	return setmetatable(tbl, {
		__index = function(self, key)
			if type(key) ~= "string" then return nil end
			local json = GamePlugin.GetJson(prefix .. "[" .. string.format("%q", key) .. "]")
			if type(json) ~= "string" or json:sub(1, 4) == "ERR|" then return nil end
			local value = JsonDecode(json)
			rawset(self, key, value)
			return value
		end
	})
end
__gameplugin_bind(GamePlugin.config.Achievement, "config.Achievement")
__gameplugin_bind(GamePlugin.config.BaseAnimSet, "config.BaseAnimSet")
__gameplugin_bind(GamePlugin.config.Cursor, "config.Cursor")
__gameplugin_bind(GamePlugin.config.DBRow, "config.DBRow")
__gameplugin_bind(GamePlugin.config.DBTable, "config.DBTable")
__gameplugin_bind(GamePlugin.config.Enum, "config.Enum")
__gameplugin_bind(GamePlugin.config.Font, "config.Font")
__gameplugin_bind(GamePlugin.config.Headbar, "config.Headbar")
__gameplugin_bind(GamePlugin.config.Hitmark, "config.Hitmark")
__gameplugin_bind(GamePlugin.config.Inv, "config.Inv")
__gameplugin_bind(GamePlugin.config.Loc, "config.Loc")
__gameplugin_bind(GamePlugin.config.MapElement, "config.MapElement")
__gameplugin_bind(GamePlugin.config.NPC, "config.NPC")
__gameplugin_bind(GamePlugin.config.Obj, "config.Obj")
__gameplugin_bind(GamePlugin.config.Param, "config.Param")
__gameplugin_bind(GamePlugin.config.Quest, "config.Quest")
__gameplugin_bind(GamePlugin.config.Seq, "config.Seq")
__gameplugin_bind(GamePlugin.config.Struct, "config.Struct")
__gameplugin_bind(GamePlugin.id.Achievement, "id.Achievement")
__gameplugin_bind(GamePlugin.id.BaseAnimSet, "id.BaseAnimSet")
__gameplugin_bind(GamePlugin.id.Category, "id.Category")
__gameplugin_bind(GamePlugin.id.Component, "id.Component")
__gameplugin_bind(GamePlugin.id.Cursor, "id.Cursor")
__gameplugin_bind(GamePlugin.id.DBRow, "id.DBRow")
__gameplugin_bind(GamePlugin.id.DBTable, "id.DBTable")
__gameplugin_bind(GamePlugin.id.Enum, "id.Enum")
__gameplugin_bind(GamePlugin.id.Font, "id.Font")
__gameplugin_bind(GamePlugin.id.Headbar, "id.Headbar")
__gameplugin_bind(GamePlugin.id.Hitmark, "id.Hitmark")
__gameplugin_bind(GamePlugin.id.Interface, "id.Interface")
__gameplugin_bind(GamePlugin.id.Inv, "id.Inv")
__gameplugin_bind(GamePlugin.id.Loc, "id.Loc")
__gameplugin_bind(GamePlugin.id.MapElement, "id.MapElement")
__gameplugin_bind(GamePlugin.id.Material, "id.Material")
__gameplugin_bind(GamePlugin.id.Model, "id.Model")
__gameplugin_bind(GamePlugin.id.Music, "id.Music")
__gameplugin_bind(GamePlugin.id.NPC, "id.NPC")
__gameplugin_bind(GamePlugin.id.Obj, "id.Obj")
__gameplugin_bind(GamePlugin.id.Param, "id.Param")
__gameplugin_bind(GamePlugin.id.Quest, "id.Quest")
__gameplugin_bind(GamePlugin.id.Seq, "id.Seq")
__gameplugin_bind(GamePlugin.id.Sound, "id.Sound")
__gameplugin_bind(GamePlugin.id.Sprite, "id.Sprite")
__gameplugin_bind(GamePlugin.id.Struct, "id.Struct")
__gameplugin_bind(GamePlugin.id.StyleSheet, "id.StyleSheet")
__gameplugin_bind(GamePlugin.id.UIAnim, "id.UIAnim")
__gameplugin_bind(GamePlugin.id.UIAnimCurve, "id.UIAnimCurve")
__gameplugin_bind(GamePlugin.id.VarClan, "id.VarClan")
__gameplugin_bind(GamePlugin.id.VarClanSetting, "id.VarClanSetting")
__gameplugin_bind(GamePlugin.id.VarClient, "id.VarClient")
__gameplugin_bind(GamePlugin.id.VarPlayer, "id.VarPlayer")
__gameplugin_bind(GamePlugin.id.VarPlayerGroup, "id.VarPlayerGroup")
