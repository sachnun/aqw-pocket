package {

	import flash.desktop.NativeApplication;
	import flash.desktop.SystemIdleMode;
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.events.ProgressEvent;
	import flash.media.SoundMixer;
	import flash.media.SoundTransform;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.system.ApplicationDomain;
	import flash.system.LoaderContext;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	import flash.ui.Keyboard;
	import flash.utils.ByteArray;
	import flash.system.Capabilities;
	import flash.utils.getTimer;

	import core.AvatarMC;
	import core.Game;
	import core.World;

	import model.Release;
	import model.Version;

	import ui.UpdateBanner;
	import input.GamePad;
	import core.ForegroundService;
	import bot.BotController;

	[SWF(width="960", height="550", frameRate="30", backgroundColor="#000")]
	public dynamic class Main extends MovieClip {

		MovieClip.prototype.removeAllChildren = function ():void {
			var i:int = this.numChildren - 1;
			while (i >= 0) {
				this.removeChildAt(i);
				i--;
			}
		};

		public static const TEXT_FORMAT_DEFAULT:TextFormat = new TextFormat("_sans", 22, 0xc8d8ee, true, null, null, null, null, TextFormatAlign.CENTER);

		private static const STATE_BACKGROUND:int = 0;
		private static const STATE_GAME:int = 1;
		private static const STATE_READY:int = 2;
		private static const BACK_EXIT_WINDOW_MS:int = 1800;

		private var loading:TextField;
		private var logField:TextField;
		private var backgroundDomain:ApplicationDomain = new ApplicationDomain();
		private var backgroundContext:LoaderContext = createLoaderContext();
		private var clientDomain:ApplicationDomain = new ApplicationDomain();
		private var clientContext:LoaderContext = createLoaderContext();
		public var gameMovieClip:MovieClip;
		private var titleFile:String;
		private var backgroundFile:String;
		private var loadState:int = STATE_BACKGROUND;
		private var foregroundService:ForegroundService;
		private var isForegroundServiceRunning:Boolean = false;
		private var lastBackPressAt:int = -BACK_EXIT_WINDOW_MS;
		private var backgroundAudioMuted:Boolean = false;
		private var masterVolumeBeforeBackground:Number = 1.0;

		private var container: Sprite = new Sprite();

		public const avatarMCCore: AvatarMC = new AvatarMC(this);
		public const gameCore: Game = new Game(this);
		public const worldCore: World = new World(this);

		public function Main() {
			foregroundService = new ForegroundService();
			const permissionRequested:Boolean = foregroundService.requestNotificationPermission();

			NativeApplication.nativeApplication.systemIdleMode = SystemIdleMode.KEEP_AWAKE;

			// Only keep the app alive in the background on Android (for foreground service).
			// On desktop (Windows/Linux), autoExit must remain true so closing the window
			// terminates the process instead of leaving it running in the background.
			const isAndroid:Boolean = Capabilities.version.substr(0, 3) == "AND";
			if (isAndroid) {
				NativeApplication.nativeApplication.autoExit = false;
				NativeApplication.nativeApplication.executeInBackground = true;
			}

			NativeApplication.nativeApplication.addEventListener(Event.ACTIVATE, onAppActivate);
			NativeApplication.nativeApplication.addEventListener(Event.DEACTIVATE, onAppDeactivate);
			NativeApplication.nativeApplication.addEventListener(Event.EXITING, onAppExiting);
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage, false, 0, true);

			addChild(container);

			prepareContext(backgroundContext);
			prepareContext(clientContext);

			loading = new TextField();
			loading.defaultTextFormat = TEXT_FORMAT_DEFAULT;
			loading.width = 400;
			loading.height = 30;
			loading.x = (960 - 400) / 2;
			loading.y = (550 - 30) / 2;
			loading.selectable = false;
			loading.text = "Loading...";

			addChild(loading);

			logField = new TextField();
			logField.defaultTextFormat = TEXT_FORMAT_DEFAULT;
			logField.width = 920;
			logField.height = 200;
			logField.x = 20;
			logField.y = 330;
			logField.multiline = true;
			logField.wordWrap = true;
			logField.selectable = true;
			logField.background = true;
			logField.backgroundColor = 0x111111;
			logField.border = true;
			logField.borderColor = 0x444444;
			logField.visible = false;

			container.addChild(logField);

			log("Init");
			if (!permissionRequested) {
				log("Notification permission request unavailable");
			}

			checkForUpdates();

			fetchJSON(Config.API_VERSION_URL, onVersionComplete);
		}

		private function onAppExiting(e:Event):void {
			NativeApplication.nativeApplication.removeEventListener(Event.ACTIVATE, onAppActivate);
			NativeApplication.nativeApplication.removeEventListener(Event.DEACTIVATE, onAppDeactivate);
			NativeApplication.nativeApplication.removeEventListener(Event.EXITING, onAppExiting);
			if (stage != null) {
				stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
			}
			NativeApplication.nativeApplication.systemIdleMode = SystemIdleMode.NORMAL;

			if (foregroundService != null) {
				foregroundService.stop();
				isForegroundServiceRunning = false;
				foregroundService.dispose();
				foregroundService = null;
			}
		}

		private function onAppActivate(e:Event):void {
			NativeApplication.nativeApplication.systemIdleMode = SystemIdleMode.KEEP_AWAKE;
			stopForegroundServiceIfRunning();
			restoreAudioAfterForeground();
		}

		private function onAppDeactivate(e:Event):void {
			NativeApplication.nativeApplication.systemIdleMode = SystemIdleMode.NORMAL;
			startForegroundServiceIfNeeded();
			muteAudioForBackground();
		}

		private function startForegroundServiceIfNeeded():void {
			if (foregroundService == null || isForegroundServiceRunning) {
				return;
			}

			isForegroundServiceRunning = foregroundService.start();
			if (!isForegroundServiceRunning) {
				log("Foreground service unavailable");
			}
		}

		private function stopForegroundServiceIfRunning():void {
			if (foregroundService == null || !isForegroundServiceRunning) {
				return;
			}

			foregroundService.stop();
			isForegroundServiceRunning = false;
		}

		private function muteAudioForBackground():void {
			if (backgroundAudioMuted) {
				return;
			}

			masterVolumeBeforeBackground = SoundMixer.soundTransform.volume;
			SoundMixer.soundTransform = new SoundTransform(0);
			backgroundAudioMuted = true;
		}

		private function restoreAudioAfterForeground():void {
			if (!backgroundAudioMuted) {
				return;
			}

			SoundMixer.soundTransform = new SoundTransform(masterVolumeBeforeBackground);
			backgroundAudioMuted = false;
		}

		private function onAddedToStage(e:Event):void {
			removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			if (stage != null) {
				stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, false, 0, true);
			}
		}

		private function onKeyDown(e:KeyboardEvent):void {
			if (e.keyCode != Keyboard.BACK) {
				return;
			}

			e.preventDefault();
			e.stopImmediatePropagation();

			const now:int = getTimer();
			if (now - lastBackPressAt <= BACK_EXIT_WINDOW_MS) {
				NativeApplication.nativeApplication.exit();
				return;
			}

			lastBackPressAt = now;
			if (foregroundService != null) {
				foregroundService.showToast("Back again to exit");
			}
		}

		private function log(msg:String):void {
			var timestamp:String = new Date().toTimeString().substr(0, 8);
			logField.appendText("[" + timestamp + "] " + msg + "\n");
			logField.scrollV = logField.maxScrollV;
		}

		private function showError(msg:String):void {
			loading.text = "Error — see log below";
			logField.visible = true;
			log("ERROR: " + msg);
		}

		public function loadMapViaBytes(url:String, context:LoaderContext, onComplete:Function, onProgress:Function = null, onError:Function = null):void {
			prepareContext(context);

			loadBinary(url,
				function (bytes:ByteArray):void {
					// Cleanup previous map loader to prevent memory leak
					if (gameMovieClip != null && gameMovieClip.world != null) {
						var oldLdr:Loader = gameMovieClip.world.ldr_map as Loader;
						if (oldLdr != null) {
							try { oldLdr.unloadAndStop(true); } catch (e:Error) {}
						}
					}

					const ldr:Loader = new Loader();

					if (gameMovieClip != null && gameMovieClip.world != null) {
						gameMovieClip.world.ldr_map = ldr;
					}

					ldr.contentLoaderInfo.addEventListener(Event.COMPLETE, function(evt:Event):void {
						ldr.contentLoaderInfo.removeEventListener(Event.COMPLETE, arguments.callee);
						onComplete(evt);
					});
					ldr.loadBytes(bytes, context);
				},
				onProgress,
				onError
			);
		}

		public function queueLoadViaBytes(ldr:Loader, url:String, context:LoaderContext):void {
			prepareContext(context);

			loadBinary(url,
				function (bytes:ByteArray):void {
					ldr.loadBytes(bytes, context);
				},
				null,
				function (e:IOErrorEvent):void {
					ldr.contentLoaderInfo.dispatchEvent(e);
				}
			);
		}

		private function advance():void {
			switch (loadState) {
				case STATE_BACKGROUND:
					loadBackground();
					break;
				case STATE_GAME:
					loadGame();
					break;
				case STATE_READY:
					attachGame();
					break;
			}
		}

		private function loadBackground():void {
			log("Loading background: " + backgroundFile);

			loading.text = "Loading Background...";

			loadSwf(
				Config.GAME_BASE_URL + "gamefiles/title/" + backgroundFile,
				backgroundContext,
				onBackgroundComplete,
				onBackgroundProgress,
				function (e:IOErrorEvent):void {
					log("Background load failed, skipping: " + e.text);
					loading.text = "Loading Game...";
					loadState = STATE_GAME;
					advance();
				}
			);
		}

		private function loadGame():void {
			log("Loading game client: " + Config.GAME_SWF_PATH);

			loading.text = "Loading Game...";

			loadSwf(
				Config.GAME_SWF_PATH,
				clientContext,
				onGameComplete,
				onGameProgress,
				function (e:IOErrorEvent):void {
					showError("Failed to load game client: " + e.text);
				}
			);
		}

		private function attachGame():void {
			log("Attaching game...");

			removeChild(container);

			gameMovieClip = MovieClip(stage.addChild(gameMovieClip));

			gameMovieClip.addChild(container);

			const params:Object = gameMovieClip.params;

			params.sTitle = titleFile;
			params.isWeb = false;
			params.sURL = Config.GAME_BASE_URL;
			params.sBG = backgroundFile;
			params.isEU = false;
			params.doSignup = false;
			params.loginURL = Config.API_LOGIN_URL;
			params.test = false;

			const rootParams:Object = root.loaderInfo.parameters;

			for (var key:String in rootParams) {
				params[key] = rootParams[key];
			}

			gameMovieClip.failedServers = {mobile: this};

			stage.setChildIndex(gameMovieClip, 0);
			stage.removeChild(DisplayObject(this));

			gameMovieClip.addChild(new GamePad(gameMovieClip));

			stage.addEventListener(Event.ENTER_FRAME, worldCore.onEnterFrame, false, 0, true);

			BotController.init(gameMovieClip, stage);
			log("Bot controller initialized");
		}

		private function checkForUpdates():void {
			if (Config.APP_VERSION == "") {
				log("Dev build — skipping update check");
				return;
			}
			log("Checking for updates...");
			fetchJSON(Config.GITHUB_RELEASES_URL, onUpdateCheckComplete);
		}

		private function showUpdateBanner(version:String, url:String):void {
			container.addChild(new UpdateBanner(version, url));
			log("Update banner shown — " + version);
		}

		private function onUpdateCheckComplete(e:Event):void {
			try {
				const release:Release = new Release(JSON.parse(URLLoader(e.target).data));

				log("Latest release: " + release.tag_name + " (current: " + Config.APP_VERSION + ")");

				if (release.tag_name != Config.APP_VERSION) {
					showUpdateBanner(release.tag_name, release.html_url);
				}
			} catch (err:Error) {
				log("Update check failed: " + err.message);
			}
		}

		private function onVersionComplete(e:Event):void {
			try {
				const version:Version = new Version(JSON.parse(URLLoader(e.target).data));
				titleFile = version.sTitle;
				backgroundFile = version.sBG;
				log("Version fetched — title: " + titleFile + ", bg: " + backgroundFile);
				advance();
			} catch (err:Error) {
				showError("Failed to parse version response: " + err.message);
			}
		}

		private function onBackgroundComplete(e:Event):void {
			log("Background loaded");

			try {
				const TitleScreenClass:Class = backgroundDomain.getDefinition("TitleScreen") as Class;
				const titleScreen:DisplayObject = new TitleScreenClass();

				titleScreen.x = 0;
				titleScreen.y = 0;

				container.addChildAt(titleScreen, 1);
			} catch (err:Error) {
				log("TitleScreen class not found, skipping: " + err.message);
			}

			loadState = STATE_GAME;
			advance();
		}

		private function onBackgroundProgress(e:ProgressEvent):void {
			loading.text = "Loading Background " + progressPercent(e) + "%";
		}

		private function onGameComplete(e:Event):void {
			log("Game client loaded");

			gameMovieClip = MovieClip(Loader(e.target.loader).content);
			loadState = STATE_READY;
			advance();
		}

		private function onGameProgress(e:ProgressEvent):void {
			loading.text = "Loading Game " + progressPercent(e) + "%";
		}

		private static function createLoaderContext():LoaderContext {
			const ctx:LoaderContext = new LoaderContext(false, new ApplicationDomain());
			ctx.allowCodeImport = true;
			return ctx;
		}

		private static function prepareContext(ctx:LoaderContext):void {
			ctx.checkPolicyFile = false;
			ctx.allowCodeImport = true;
		}

		private static function progressPercent(e:ProgressEvent):int {
			return int((e.currentTarget.bytesLoaded / e.currentTarget.bytesTotal) * 100);
		}

		private static function loadBinary(url:String, onBytes:Function, onProgress:Function = null, onError:Function = null):void {
			const ul:URLLoader = new URLLoader();
			ul.dataFormat = URLLoaderDataFormat.BINARY;

			var completeHandler:Function;
			var errorHandler:Function;

			var cleanup:Function = function():void {
				ul.removeEventListener(Event.COMPLETE, completeHandler);
				if (onProgress != null) {
					ul.removeEventListener(ProgressEvent.PROGRESS, onProgress);
				}
				ul.removeEventListener(IOErrorEvent.IO_ERROR, errorHandler);
				try { ul.close(); } catch (e:Error) {}
				ul.data = null;
			};

			completeHandler = function(e:Event):void {
				var bytes:ByteArray = URLLoader(e.target).data as ByteArray;
				cleanup();
				onBytes(bytes);
			};

			errorHandler = function(e:IOErrorEvent):void {
				cleanup();
				if (onError != null) {
					onError(e);
				}
			};

			ul.addEventListener(Event.COMPLETE, completeHandler);
			if (onProgress != null) {
				ul.addEventListener(ProgressEvent.PROGRESS, onProgress);
			}
			ul.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);

			ul.load(new URLRequest(url));
		}

		private static function loadSwf(url:String, context:LoaderContext, onComplete:Function, onProgress:Function = null, onError:Function = null):void {
			loadBinary(url,
				function (bytes:ByteArray):void {
					const ldr:Loader = new Loader();

					var completeWrapper:Function;
					var errorWrapper:Function;

					var cleanupListeners:Function = function():void {
						ldr.contentLoaderInfo.removeEventListener(Event.COMPLETE, completeWrapper);
						if (errorWrapper != null) {
							ldr.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, errorWrapper);
						}
					};

					completeWrapper = function(e:Event):void {
						cleanupListeners();
						onComplete(e);
					};

					if (onError != null) {
						errorWrapper = function(e:IOErrorEvent):void {
							cleanupListeners();
							onError(e);
						};
						ldr.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, errorWrapper);
					}

					ldr.contentLoaderInfo.addEventListener(Event.COMPLETE, completeWrapper);
					ldr.loadBytes(bytes, context);
				},
				onProgress,
				onError
			);
		}

		private static function fetchJSON(url:String, onComplete:Function):void {
			const ul:URLLoader = new URLLoader();
			var handler:Function = function(e:Event):void {
				ul.removeEventListener(Event.COMPLETE, handler);
				try { ul.close(); } catch (err:Error) {}
				onComplete(e);
				ul.data = null;
			};
			ul.addEventListener(Event.COMPLETE, handler);
			ul.load(new URLRequest(url));
		}
	}
}
