package;

import lime.app.Future;
import openfl.system.System;
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import lime.utils.Assets;
import flixel.system.FlxSound;
import openfl.utils.Assets as OpenFlAssets;
import WeekData;
#if sys
import openfl.system.System;
#end
import openfl.net.URLRequest;
import openfl.media.Sound;
import haxe.Json;

using StringTools;

class FreeplayState extends MusicBeatState
{
	public static var songs:Array<SongMetadata> = [];

	var selector:FlxText;
	private static var curSelected:Int = 0;
	var curDifficulty:Int = 2;

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	var bg:FlxSprite;
	var intendedColor:Int;
	var colorTween:FlxTween;

	public static var onlineSongs:Map<String, Array<String>> = new Map<String, Array<String>>();
	override function create()
	{
		songs = [];
		openfl.Assets.cache.clear("assets");
		openfl.Assets.cache.clear("songs");
		openfl.Assets.cache.clear("images");

		PlayState.inst = null;
		PlayState.voices = null;
		PlayState.SONG = null;

		System.gc();

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		for (i in 0...WeekData.weeksList.length) {
			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var leSongs:Array<String> = [];
			var leChars:Array<String> = [];

			for (j in 0...leWeek.songs.length)
			{
				leSongs.push(leWeek.songs[j][0]);
				leChars.push(leWeek.songs[j][1]);
			}

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if(colors == null || colors.length < 3)
				{
					colors = [146, 113, 253];
				}
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}

		#if !html5
		var http = new haxe.Http('http://sancopublic.ddns.net:5430/api/collections/fnf_charts/records');
		http.onData = function(data:String)
		{
			var onlineSongItems = cast Json.parse(data).items;
			for(i in 0...onlineSongItems.length)
			{
				var onlineSongItemName = onlineSongItems[i].song_name;

				var chartPath = 'http://sancopublic.ddns.net:5430/api/files/fnf_charts/' + onlineSongItems[i].id + "/" + onlineSongItems[i].chart_file;
				var instPath = 'http://sancopublic.ddns.net:5430/api/files/fnf_charts/' + onlineSongItems[i].id + "/" + onlineSongItems[i].inst;
				var voicesPath = 'http://sancopublic.ddns.net:5430/api/files/fnf_charts/' + onlineSongItems[i].id + "/" + onlineSongItems[i].voices;

				addSong(onlineSongItemName, i, "face", FlxColor.fromRGB(0, 0, 0), true);
				onlineSongs.set(onlineSongItemName, [chartPath, instPath, voicesPath, onlineSongItems[i].difficulty]);
				
				System.gc();
			}
			regenMenu();
		}
		http.request();
		#else
		var request = js.Browser.createXMLHttpRequest();
		request.addEventListener('load', function()
		{
			var onlineSongItems:Dynamic = cast Json.parse(request.responseText).items;
			for(i in 0...onlineSongItems.length)
			{
				var onlineSongItemName = onlineSongItems[i].song_name;

				var chartPath = 'http://sancopublic.ddns.net:5430/api/files/fnf_charts/' + onlineSongItems[i].id + "/" + onlineSongItems[i].chart_file;
				var instPath = 'http://sancopublic.ddns.net:5430/api/files/fnf_charts/' + onlineSongItems[i].id + "/" + onlineSongItems[i].inst;
				var voicesPath = 'http://sancopublic.ddns.net:5430/api/files/fnf_charts/' + onlineSongItems[i].id + "/" + onlineSongItems[i].voices;

				addSong(onlineSongItemName, i, "face", FlxColor.fromRGB(0, 0, 0), true);
				onlineSongs.set(onlineSongItemName, [chartPath, instPath, voicesPath, onlineSongItems[i].difficulty]);

				System.gc();
			}

			regenMenu();
		});
		request.open("GET", 'http://sancopublic.ddns.net:5430/api/collections/fnf_charts/records');
		request.send();
		#end

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);
		bg.screenCenter();

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		WeekData.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "HARD", 24);
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);

		if(curSelected >= songs.length) curSelected = 0;
		bg.color = songs[curSelected].color;
		intendedColor = bg.color;

		changeSelection();

		#if (android)
		addVirtualPad(UP_DOWN, A_B);
		#end

		super.create();
	}

	public static function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int, onlineSong:Bool = false)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color, onlineSong));
	}

	var instPlaying:Int = -1;
	private static var vocals:FlxSound = null;
	var holdTime:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}

		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, CoolUtil.boundTo(elapsed * 24, 0, 1)));
		lerpRating = FlxMath.lerp(lerpRating, intendedRating, CoolUtil.boundTo(elapsed * 12, 0, 1));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(Highscore.floorDecimal(lerpRating * 100, 2)).split('.');
		if(ratingSplit.length < 2) { //No decimals, add an empty space
			ratingSplit.push('');
		}
		
		while(ratingSplit[1].length < 2) { //Less than 2 decimals in it, add decimals then
			ratingSplit[1] += '0';
		}

		scoreText.text = 'PERSONAL BEST: ' + lerpScore + ' (' + ratingSplit.join('.') + '%)';
		positionHighscore();

		var upP = controls.UI_UP_P;
		var downP = controls.UI_DOWN_P;
		var accepted = controls.ACCEPT;
		var space = FlxG.keys.justPressed.SPACE;

		var shiftMult:Int = 1;
		if(FlxG.keys.pressed.SHIFT) shiftMult = 3;

		if(songs.length > 1)
		{
			if (upP)
			{
				changeSelection(-shiftMult);
				holdTime = 0;
			}
			if (downP)
			{
				changeSelection(shiftMult);
				holdTime = 0;
			}

			if(controls.UI_DOWN || controls.UI_UP)
			{
				var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
				holdTime += elapsed;
				var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

				if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
				{
					changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
				}
			}
		}

		if (controls.BACK)
		{
			if(colorTween != null) {
				colorTween.cancel();
			}
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
		}

		if (accepted) //???
		{
			if(songs[curSelected].onlineSong)
			{
				#if !html5
				var http = new haxe.Http(onlineSongs[songs[curSelected].songName][0]);
				http.onData = function(data:String)
				{
					persistentUpdate = false;

					var the = Song.parseJSONshit(data);

					PlayState.SONG = the;
					PlayState.isStoryMode = false;
					PlayState.storyDifficulty = curDifficulty;
					PlayState.inst = new Sound(new URLRequest(onlineSongs[songs[curSelected].songName][1]));
					PlayState.voices = new Sound(new URLRequest(onlineSongs[songs[curSelected].songName][2]));
					PlayState.onlineSong = true;
		
					if(colorTween != null) {
						colorTween.cancel();
					}
					if(FlxG.keys.pressed.SHIFT)
					{
						LoadingState.loadAndSwitchState(new ChartingState());
					}
					else
					{
						LoadingState.loadAndSwitchState(new PlayState());
					}
		
					if(FlxG.sound.music != null){
						FlxG.sound.music.volume = 0;
					}
		
					destroyFreeplayVocals();
					
					System.gc();
				}
				http.request();
				#else
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = curDifficulty;
				PlayState.onlineSong = true;

				var request = js.Browser.createXMLHttpRequest();
				request.addEventListener('load', function()
				{
					System.gc();

					trace("Got chart data");
					PlayState.SONG = Song.parseJSONshit(request.responseText);
					trace("Now trying to get inst using Future");
					Sound.loadFromFile(onlineSongs[songs[curSelected].songName][1]).then(function(inst)
					{
						trace("Successfully got inst");
						PlayState.inst = inst;
						return Future.withValue(inst);
					});
					if(PlayState.SONG.needsVoices)
					{
						trace("Song needs voices, trying to get vocals using Future");
						Sound.loadFromFile(onlineSongs[songs[curSelected].songName][2]).then(function(vocals)
						{
							trace("Successfully got vocals");
							PlayState.voices = vocals;
							trace("Seems like nothing more is needed, switching to Playstate");

							persistentUpdate = false;

							if(FlxG.sound.music != null){
								FlxG.sound.music.volume = 0;
							}
		
							destroyFreeplayVocals();

							if(colorTween != null) {
								colorTween.cancel();
							}

							if(FlxG.keys.pressed.SHIFT)
							{
								LoadingState.loadAndSwitchState(new ChartingState());
							}
							else
							{
								LoadingState.loadAndSwitchState(new PlayState());
							}
							return Future.withValue(vocals);
						});
					}
					else
					{
						trace("Seems like nothing more is needed, switching to Playstate");
						persistentUpdate = false;
						if(FlxG.sound.music != null){
							FlxG.sound.music.volume = 0;
						}
	
						destroyFreeplayVocals();
						
						if(colorTween != null) {
							colorTween.cancel();
						}
						if(FlxG.keys.pressed.SHIFT)
						{
							LoadingState.loadAndSwitchState(new ChartingState());
						}
						else
						{
							LoadingState.loadAndSwitchState(new PlayState());
						}
					}
				});
				request.open("GET", onlineSongs[songs[curSelected].songName][0]); //we tryna to get the chart data
				request.send();
				#end
			}
			else
			{
				persistentUpdate = false;
			
				var songLowercase:String = songs[curSelected].songName.toLowerCase().replace(' ', '-');
				var poop:String = Highscore.formatSong(songLowercase, curDifficulty);
				trace(poop);
	
				PlayState.SONG = Song.loadFromJson(poop, songLowercase);
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = curDifficulty;
				PlayState.inst = Paths.inst(PlayState.SONG.song);
				PlayState.voices = Paths.voices(PlayState.SONG.song);
				PlayState.onlineSong = false;
	
				trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
				if(colorTween != null) {
					colorTween.cancel();
				}
				if(FlxG.keys.pressed.SHIFT)
				{
					LoadingState.loadAndSwitchState(new ChartingState());
				}
				else
				{
					LoadingState.loadAndSwitchState(new PlayState());
				}
	
				FlxG.sound.music.volume = 0;
	
				destroyFreeplayVocals();
			}
		}

		if(controls.RESET)
		{
			regenMenu();
		}

		if(songs[curSelected].onlineSong)
		{
			//hard code it even if its a different diff
			curDifficulty = 2;
			diffText.text = onlineSongs[songs[curSelected].songName][3].toUpperCase();
		}
		else
		{
			if(songs[curSelected].songName == "Betrayal")
				{
					curDifficulty = 3;
					diffText.text = "BLACKOUT";
				}
				else
				{
					curDifficulty = 2;
					diffText.text = "HARD";
				}
		}

		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);

		super.update(elapsed);
	}

	public static function destroyFreeplayVocals() {
		if(vocals != null) {
			vocals.stop();
			vocals.destroy();
		}
		vocals = null;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = songs.length - 1;
		if (curSelected >= songs.length)
			curSelected = 0;
			
		var newColor:Int = songs[curSelected].color;
		if(newColor != intendedColor) {
			if(colorTween != null) {
				colorTween.cancel();
			}
			intendedColor = newColor;
			colorTween = FlxTween.color(bg, 1, bg.color, intendedColor, {
				onComplete: function(twn:FlxTween) {
					colorTween = null;
				}
			});
		}

		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		var bullShit:Int = 0;

		for (item in grpSongs.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;

			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
		
		PlayState.storyWeek = songs[curSelected].week;
	}

	private function positionHighscore() {
		scoreText.x = FlxG.width - scoreText.width - 6;

		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}

	function regenMenu()
    {
        grpSongs.clear();

        for(i in 0...songs.length)
        {
			var songText:Alphabet = new Alphabet(0, (70 * i) + 30, songs[i].songName, true, false);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpSongs.add(songText);

			if (songText.width > 980)
			{
				var textScale:Float = 980 / songText.width;
				songText.scale.x = textScale;
				for (letter in songText.lettersArray)
				{
					letter.x *= textScale;
					letter.offset.x *= textScale;
				}
			}
        }

        curSelected = 0;
        changeSelection();
    }
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var onlineSong:Bool = false;

	public function new(song:String, week:Int, songCharacter:String, color:Int, onlineSong:Bool)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.onlineSong = onlineSong;
	}
}