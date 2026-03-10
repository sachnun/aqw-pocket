package bot {

	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.utils.Timer;

	import bot.api.AurasAPI;
	import bot.api.CombatAPI;
	import bot.api.MonsterAPI;
	import bot.api.PlayerAPI;
	import bot.api.ShopAPI;
	import bot.api.SkillsAPI;
	import bot.api.WorldAPI;
	import bot.module.Modules;
	import bot.packet.PacketHandler;

	/**
	 * BotController - the central orchestrator for all bot hooks.
	 * Replaces ExternalInterface as the communication layer.
	 *
	 * Provides high-level bot operations built on top of the API classes:
	 * - Auto-attack with proper cooldown management and skill rotation
	 * - Monster targeting with smart selection (lowest HP first)
	 * - Auto-hunt: target + attack + loot loop
	 * - Module management (hide players, disable FX, etc.)
	 *
	 * Usage from Main.as:
	 *   BotController.init(gameMovieClip, stage);
	 *   BotController.startAutoAttack("Slime");
	 */
	public class BotController {

		// Auto-attack state
		private static var _autoAttackTimer:Timer;
		private static var _autoAttackTarget:String = "*";
		private static var _autoAttackActive:Boolean = false;
		private static var _autoSkillIndex:int = 0;
		private static var _autoSkillOrder:Array = [0, 1, 2, 3, 4, 5];
		private static var _autoSkillEnabled:Object = {};

		// Auto-hunt state
		private static var _autoHuntActive:Boolean = false;
		private static var _autoHuntCell:String = "";
		private static var _autoHuntPad:String = "Left";
		private static var _autoHuntMonster:String = "*";
		private static var _autoHuntDropWhitelist:String = "";

		// General state
		private static var _initialized:Boolean = false;
		private static var _stage:*;

		private static const AUTO_ATTACK_INTERVAL:int = 800;

		/**
		 * Initialize the bot controller.
		 * Must be called after the game is fully loaded.
		 */
		public static function init(game:MovieClip, stage:*):void {
			if (_initialized) return;

			GameAccessor.init(game);
			_stage = stage;

			// Init modules
			Modules.init();
			stage.addEventListener(Event.ENTER_FRAME, Modules.handleFrame);

			// Init auras
			AurasAPI.initialize();

			// Init auto-attack timer
			_autoAttackTimer = new Timer(AUTO_ATTACK_INTERVAL);
			_autoAttackTimer.addEventListener(TimerEvent.TIMER, onAutoAttackTick);

			// Enable all skills by default
			for (var i:int = 0; i < 6; i++) {
				_autoSkillEnabled[i] = true;
			}

			_initialized = true;
		}

		/** Check if the controller is initialized */
		public static function get initialized():Boolean {
			return _initialized;
		}

		// ==========================================
		// AUTO-ATTACK
		// ==========================================

		/**
		 * Start auto-attacking monsters matching the given name.
		 * Use "*" for any monster in the current cell.
		 */
		public static function startAutoAttack(monsterName:String = "*"):void {
			_autoAttackTarget = monsterName;
			_autoAttackActive = true;
			_autoSkillIndex = 0;
			_autoAttackTimer.start();
		}

		/** Stop auto-attack */
		public static function stopAutoAttack():void {
			_autoAttackActive = false;
			_autoAttackTimer.stop();
		}

		/** Check if auto-attack is active */
		public static function get autoAttackActive():Boolean {
			return _autoAttackActive;
		}

		/** Get current auto-attack target name */
		public static function get autoAttackTarget():String {
			return _autoAttackTarget;
		}

		/** Toggle a skill in the auto-attack rotation (index 0-5) */
		public static function toggleAutoSkill(index:int):void {
			_autoSkillEnabled[index] = !(_autoSkillEnabled[index] === true);
		}

		/** Check if a skill is enabled in auto-attack */
		public static function isAutoSkillEnabled(index:int):Boolean {
			return _autoSkillEnabled[index] === true;
		}

		/** Set all skills enabled/disabled in auto-attack */
		public static function setAllAutoSkills(enabled:Boolean):void {
			for (var i:int = 0; i < 6; i++) {
				_autoSkillEnabled[i] = enabled;
			}
		}

		private static function onAutoAttackTick(e:TimerEvent):void {
			if (!_autoAttackActive) return;

			try {
				var game:* = GameAccessor.game;
				if (game == null || game.world == null || game.world.myAvatar == null) return;

				// Check if we need a new target
				if (!MonsterAPI.hasTarget() || !MonsterAPI.isTargetAlive()) {
					MonsterAPI.attackMonsterByName(_autoAttackTarget);
					return; // Wait for next tick to start attacking
				}

				// Approach target
				CombatAPI.approachTarget();

				// Cycle through enabled skills
				var enabledSkills:Array = getEnabledAutoSkills();
				if (enabledSkills.length == 0) return;

				var attempts:int = 0;
				while (attempts < enabledSkills.length) {
					var skillIdx:int = enabledSkills[_autoSkillIndex % enabledSkills.length];
					_autoSkillIndex++;

					if (SkillsAPI.canUseSkill(skillIdx)) {
						SkillsAPI.useSkill(skillIdx);
						break;
					}
					attempts++;
				}
			} catch (err:Error) {
				// Silently handle errors to keep the timer running
			}
		}

		private static function getEnabledAutoSkills():Array {
			var result:Array = [];
			for each (var idx:int in _autoSkillOrder) {
				if (_autoSkillEnabled[idx] === true) {
					result.push(idx);
				}
			}
			return result;
		}

		// ==========================================
		// AUTO-HUNT (target + kill + loot loop)
		// ==========================================

		/**
		 * Start auto-hunting: kills monsters in a cell, optionally rejects unwanted drops.
		 * @param monsterName Monster name or "*" for any
		 * @param cell Cell to fight in (empty = current cell)
		 * @param pad Pad to use (default "Left")
		 * @param dropWhitelist Comma-separated list of drop names to keep. Empty = keep all.
		 */
		public static function startAutoHunt(monsterName:String = "*", cell:String = "", pad:String = "Left", dropWhitelist:String = ""):void {
			_autoHuntMonster = monsterName;
			_autoHuntCell = cell;
			_autoHuntPad = pad;
			_autoHuntDropWhitelist = dropWhitelist;
			_autoHuntActive = true;

			// Navigate to cell if specified
			if (cell != "" && cell != PlayerAPI.getCurrentCell()) {
				WorldAPI.moveToCell(cell, pad);
			}

			// Start attacking
			startAutoAttack(monsterName);
		}

		/** Stop auto-hunting */
		public static function stopAutoHunt():void {
			_autoHuntActive = false;
			stopAutoAttack();
		}

		/** Check if auto-hunt is active */
		public static function get autoHuntActive():Boolean {
			return _autoHuntActive;
		}

		/** Reject unwanted drops (call this periodically or after kills) */
		public static function rejectUnwantedDrops():void {
			if (_autoHuntDropWhitelist != "") {
				try {
					PlayerAPI.rejectExcept(_autoHuntDropWhitelist);
				} catch (e:Error) {}
			}
		}

		// ==========================================
		// MODULE SHORTCUTS
		// ==========================================

		public static function toggleHidePlayers():Boolean {
			return Modules.toggle("HidePlayers");
		}

		public static function toggleDisableCollisions():Boolean {
			return Modules.toggle("DisableCollisions");
		}

		public static function isHidePlayersEnabled():Boolean {
			return Modules.isEnabled("HidePlayers");
		}

		public static function isDisableCollisionsEnabled():Boolean {
			return Modules.isEnabled("DisableCollisions");
		}

		// ==========================================
		// QUICK ACTIONS
		// ==========================================

		/** Quick attack a monster by name */
		public static function attackMonster(name:String):Boolean {
			return MonsterAPI.attackMonsterByName(name);
		}

		/** Quick navigate to cell */
		public static function goToCell(cell:String, pad:String = "Left"):void {
			WorldAPI.moveToCell(cell, pad);
		}

		/** Quick use skill by index */
		public static function useSkill(index:int):Boolean {
			return SkillsAPI.useSkill(index);
		}

		/** Enable infinite range on all skills */
		public static function enableInfiniteRange():void {
			CombatAPI.infiniteRange();
		}

		/** Magnetize current target to player position */
		public static function magnetizeTarget():void {
			CombatAPI.magnetize();
		}

		/** Skip current cutscene */
		public static function skipCutscene():void {
			WorldAPI.skipCutscenes();
		}

		/** Toggle kill lag mode */
		public static function toggleKillLag(enable:Boolean):void {
			WorldAPI.killLag(enable);
		}

		// ==========================================
		// STATUS
		// ==========================================

		/** Get a summary of the current bot state */
		public static function getStatus():Object {
			return {
				initialized: _initialized,
				autoAttack: _autoAttackActive,
				autoAttackTarget: _autoAttackTarget,
				autoHunt: _autoHuntActive,
				hidePlayers: Modules.isEnabled("HidePlayers"),

				disableCollisions: Modules.isEnabled("DisableCollisions"),
				questItemRates: Modules.isEnabled("QuestItemRates"),
				packetCapture: PacketHandler.isCapturing()
			};
		}

		// ==========================================
		// CLEANUP
		// ==========================================

		/** Dispose all resources */
		public static function dispose():void {
			stopAutoAttack();
			stopAutoHunt();
			PacketHandler.dispose();
			AurasAPI.dispose();
			Modules.dispose();

			if (_stage != null) {
				_stage.removeEventListener(Event.ENTER_FRAME, Modules.handleFrame);
			}

			_autoAttackTimer.removeEventListener(TimerEvent.TIMER, onAutoAttackTick);
			_autoAttackTimer = null;
			_stage = null;
			_initialized = false;
		}
	}
}
