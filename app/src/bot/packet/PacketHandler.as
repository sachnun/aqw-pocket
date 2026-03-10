package bot.packet {

	import bot.GameAccessor;

	/**
	 * Packet Handler - provides SmartFoxServer packet interception and injection.
	 * Provides SmartFoxServer packet interception and injection.
	 *
	 * - catchPackets(): start listening for extension response packets
	 * - sendClientPacket(): inject a packet as if it came from the server
	 *
	 * Packet types:
	 * - "xml": XML format packets
	 * - "json": JSON format packets
	 * - "str": String format packets (most common in AQW, prefixed with %xt%zm%)
	 */
	public class PacketHandler {

		private static var _handler:* = null;
		private static var _listening:Boolean = false;
		private static var _packetLog:Array = [];
		private static var _maxLogSize:int = 200;
		private static var _onPacketCallback:Function = null;

		/** Start listening for SmartFoxServer extension response packets */
		public static function startCapture(onPacket:Function = null):void {
			if (_listening) return;

			var game:* = GameAccessor.game;
			if (game == null || game.sfc == null) return;

			_onPacketCallback = onPacket;
			game.sfc.addEventListener(SFSEvent.onDebugMessage, onPacketReceived);
			_listening = true;
		}

		/** Stop listening for packets */
		public static function stopCapture():void {
			if (!_listening) return;

			try {
				var game:* = GameAccessor.game;
				if (game != null && game.sfc != null) {
					game.sfc.removeEventListener(SFSEvent.onDebugMessage, onPacketReceived);
				}
			} catch (e:Error) {}

			_listening = false;
			_onPacketCallback = null;
		}

		/** Check if currently capturing packets */
		public static function isCapturing():Boolean {
			return _listening;
		}

		/**
		 * Send a packet to the client as if it came from the server.
		 * This spoofs the server response handler.
		 *
		 * @param packet The packet string to process
		 * @param type Packet type: "xml", "json", or "str"
		 */
		public static function sendClientPacket(packet:String, type:String):void {
			ensureHandler();
			if (_handler == null) return;

			switch (type) {
				case "xml":
					_handler.handleMessage(new XML(packet), "xml");
					break;
				case "json":
					_handler.handleMessage(JSON.parse(packet)["b"], "json");
					break;
				case "str":
					var array:Array = packet.substr(1, packet.length - 2).split("%");
					_handler.handleMessage(array.splice(1, array.length - 1), "str");
					break;
			}
		}

		/** Get the packet log (most recent captured packets) */
		public static function getPacketLog():Array {
			return _packetLog.slice();
		}

		/** Clear the packet log */
		public static function clearPacketLog():void {
			_packetLog = [];
		}

		/** Set the maximum number of packets to keep in the log */
		public static function setMaxLogSize(size:int):void {
			_maxLogSize = size;
			while (_packetLog.length > _maxLogSize) {
				_packetLog.shift();
			}
		}

		/** Send a raw server packet (xt message) */
		public static function sendServerPacket(cmd:String, params:Array = null, type:String = "str"):void {
			var game:* = GameAccessor.game;
			if (game == null || game.sfc == null || game.world == null) return;

			if (params == null) params = [];
			game.sfc.sendXtMessage("zm", cmd, params, type, game.world.curRoom);
		}

		private static function ensureHandler():void {
			if (_handler != null) return;

			try {
				var game:* = GameAccessor.game;
				var domain:* = game.loaderInfo.applicationDomain;
				var cls:Class = Class(domain.getDefinition("it.gotoandplay.smartfoxserver.handlers.ExtHandler"));
				_handler = new cls(game.sfc);
			} catch (e:Error) {
				_handler = null;
			}
		}

		private static function onPacketReceived(packet:*):void {
			if (packet == null || packet.params == null || packet.params.message == null) return;

			var msg:String = packet.params.message;
			if (msg.indexOf("%xt%zm%") > -1) {
				var cleanPacket:String = msg.split(":", 2)[1];
				if (cleanPacket != null) {
					cleanPacket = cleanPacket.replace(/^\s+|\s+$/g, "");

					// Add to log
					_packetLog.push(cleanPacket);
					if (_packetLog.length > _maxLogSize) {
						_packetLog.shift();
					}

					// Call callback if set
					if (_onPacketCallback != null) {
						try {
							_onPacketCallback(cleanPacket);
						} catch (e:Error) {}
					}
				}
			}
		}

		/** Cleanup resources */
		public static function dispose():void {
			stopCapture();
			_handler = null;
			_packetLog = [];
		}
	}
}
