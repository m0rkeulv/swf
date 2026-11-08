package tests;

import haxe.Json;
import openfl.filters.BitmapFilterType;
import openfl.utils.Assets;
import swf.exporters.animate.AnimateFilterType;
import swf.exporters.animate.AnimateFrameObjectType;
import swf.exporters.animate.AnimateLibrary;
import swf.exporters.animate.AnimateShapeCommandType;
import swf.exporters.animate.AnimateSymbol;
import swf.exporters.animate.AnimateSymbolType;
import swf.exporters.animate.binary.AnimateBinaryReader;
import swf.exporters.animate.binary.AnimateBinaryWriter;
import swf.exporters.animate.document.*;
import swf.exporters.animate.json.AnimateJsonWriter;
import utest.Assert;
import utest.Test;

/**
	An `animate-binary` bundle must give the same symbols as the `animate` bundle of the same SWF.
	`project.xml` builds both from `fixtures/shapes.swf`; the other tests take a document with every
	symbol type and every field through both writers in memory, the JSON through the loader's own parse
	functions, so the two paths are compared field by field without the build tool.
**/
@:access(swf.exporters.animate.AnimateLibrary)
class AnimateBinaryTest extends Test
{
	public function testBundlesMatch():Void
	{
		var json:AnimateLibrary = cast Assets.getLibrary("shapes_json");
		var binary:AnimateLibrary = cast Assets.getLibrary("shapes_binary");
		Assert.notNull(json);
		Assert.notNull(binary);
		Assert.equals(json.frameRate, binary.frameRate);

		var count = 0;
		for (id in json.symbols.keys())
		{
			count++;
			var difference = SymbolCompare.difference(json.symbols.get(id), binary.symbols.get(id), 'symbol $id');
			Assert.isNull(difference, difference);
		}
		var otherCount = 0;
		for (id in binary.symbols.keys())
			otherCount++;
		Assert.equals(count, otherCount);
		Assert.isTrue(count > 1);
		var difference = SymbolCompare.difference(json.root, binary.root, "root");
		Assert.isNull(difference, difference);
	}

	public function testEveryFieldBothWays():Void
	{
		var document = fullDocument();
		var symbols = document.symbolList();

		var binary = AnimateBinaryReader.read(AnimateBinaryWriter.write(document.frameRate, document.uuid, symbols));
		Assert.equals(document.frameRate, binary.frameRate);
		Assert.equals(document.uuid, binary.uuid);
		Assert.equals(0, binary.rootIndex);
		Assert.equals(symbols.length, binary.symbols.length);

		var json:Dynamic = Json.parse(AnimateJsonWriter.stringify(document));
		Assert.equals(document.frameRate, json.frameRate);
		Assert.equals(document.uuid, json.uuid);
		Assert.equals(0, json.root);
		var jsonSymbols:Array<Dynamic> = json.symbols;
		Assert.equals(symbols.length, jsonSymbols.length);

		var library:AnimateLibrary = cast Assets.getLibrary("shapes_json");
		for (i in 0...symbols.length)
		{
			var fromJson = parseAsLoader(library, jsonSymbols[i]);
			Assert.notNull(fromJson);
			var difference = SymbolCompare.difference(fromJson, binary.symbols[i], 'symbol ${symbols[i].id}');
			Assert.isNull(difference, difference);
		}
	}

	/**
		The exporter names every symbol that has a linkage, but the loader reads the name of bitmaps,
		buttons and sprites only, so a font, shape or text exported for ActionScript is not registered by
		its class name; both readers must agree, or the two bundles would register different classes.
	**/
	public function testClassNameOnlyWhereJsonReadsIt():Void
	{
		var document = fullDocument();
		var symbols = document.symbolList();
		var binary = AnimateBinaryReader.read(AnimateBinaryWriter.write(document.frameRate, document.uuid, symbols));
		var jsonSymbols:Array<Dynamic> = Json.parse(AnimateJsonWriter.stringify(document)).symbols;
		var library:AnimateLibrary = cast Assets.getLibrary("shapes_json");

		var kept = [], dropped = [];
		for (i in 0...symbols.length)
		{
			Assert.notNull(symbols[i].className);
			var fromJson = parseAsLoader(library, jsonSymbols[i]);
			Assert.equals(fromJson.className, binary.symbols[i].className);
			(fromJson.className != null ? kept : dropped).push(symbols[i].className);
		}
		kept.sort(Reflect.compare);
		dropped.sort(Reflect.compare);
		Assert.same(["Root", "assets.Bitmap", "assets.Plain", "clips.Clip", "ui.Button"], kept);
		Assert.same(["fonts.Font", "shapes.Rect", "ui.Label", "ui.Text"], dropped);
	}

	/** What `AnimateLibrary.load()` makes of one symbol of a `data.json`. **/
	private static function parseAsLoader(library:AnimateLibrary, data:Dynamic):AnimateSymbol
	{
		var type:AnimateSymbolType = data.type;
		return switch (type)
		{
			case BITMAP: library.__parseBitmap(data);
			case BUTTON: library.__parseButton(data);
			case DYNAMIC_TEXT: library.__parseDynamicText(data);
			case FONT: library.__parseFont(data);
			case SHAPE: library.__parseShape(data);
			case SPRITE: library.__parseSprite(data);
			case STATIC_TEXT: library.__parseStaticText(data);
			default: null;
		}
	}

	/** A document with every symbol type, every field the exporter can set, and every shape command. **/
	private static function fullDocument():AnimateDocument
	{
		var document = new AnimateDocument();
		document.frameRate = 24;
		document.uuid = "0123456789abcdefghij";

		var bitmap = new AnimateDocumentBitmap();
		bitmap.id = 1;
		bitmap.className = "assets.Bitmap";
		bitmap.baseClassName = "flash.display.BitmapData";
		bitmap.path = "symbols/1.jpg";
		bitmap.alpha = "symbols/1a.png";
		bitmap.smooth = true;
		document.symbols.set(1, bitmap);

		var plain = new AnimateDocumentBitmap();
		plain.id = 2;
		plain.className = "assets.Plain";
		plain.path = "symbols/2.png";
		document.symbols.set(2, plain);

		var shape = new AnimateDocumentShape();
		shape.id = 3;
		shape.className = "shapes.Rect";
		shape.commands = [
			AnimateShapeCommandType.LINE_STYLE, 2.5, 0xFF0000, 1, true, 0, 1, 2, 3,
			AnimateShapeCommandType.BEGIN_FILL, 0x00FF00, 0.5,
			AnimateShapeCommandType.MOVE_TO, 0, 0,
			AnimateShapeCommandType.LINE_TO, 2000, 0,
			AnimateShapeCommandType.CURVE_TO, 2000, 1000, 1000, 2000,
			AnimateShapeCommandType.END_FILL,
			AnimateShapeCommandType.BEGIN_GRADIENT_FILL, 1, [0xFF0000, 0x0000FF], [1, 0.25], [0, 255], [1, 0, 0, 1, 200, 400], 0, 1, 0.75,
			AnimateShapeCommandType.LINE_TO, -400, 60,
			AnimateShapeCommandType.BEGIN_BITMAP_FILL, 1, [2, 0, 0, 2, 0, 0], true, false,
			AnimateShapeCommandType.CLEAR_LINE_STYLE,
			AnimateShapeCommandType.LINE_STYLE, 1, 0, 1, false, 2, 0, 1, 10,
			AnimateShapeCommandType.END_FILL
		];
		document.symbols.set(3, shape);

		var font = new AnimateDocumentFont();
		font.id = 4;
		font.className = "fonts.Font";
		font.name = "Test Font";
		font.ascent = 900;
		font.descent = 200;
		font.leading = 50;
		font.bold = true;
		font.italic = false;
		font.codes = [65, 66, 67];
		font.advances[0] = 600;
		font.advances[2] = 550; // a gap at 1, as glyph 1 is never used
		font.glyphs[0] = [
			AnimateShapeCommandType.BEGIN_FILL, 0, 1,
			AnimateShapeCommandType.MOVE_TO, 0, 0,
			AnimateShapeCommandType.LINE_TO, 100, 0,
			AnimateShapeCommandType.END_FILL
		];
		font.glyphs[2] = [AnimateShapeCommandType.MOVE_TO, 0, 0, AnimateShapeCommandType.CURVE_TO, 50, 50, 100, 0];
		document.symbols.set(4, font);

		var text = new AnimateDocumentDynamicText();
		text.id = 5;
		text.className = "ui.Text";
		text.align = "center";
		text.border = true;
		text.color = 0x123456;
		text.fontHeight = 240;
		text.fontID = 4;
		text.fontName = "Test Font";
		text.html = true;
		text.indent = 10;
		text.input = false;
		text.leading = 2;
		text.leftMargin = 4;
		text.multiline = true;
		text.password = false;
		text.rect = [0, 0, 4000, 600];
		text.rightMargin = 6;
		text.selectable = true;
		text.text = "Hello, <b>world</b> ÆØÅ";
		text.wordWrap = true;
		document.symbols.set(5, text);

		var label = new AnimateDocumentStaticText();
		label.id = 6;
		label.className = "ui.Label";
		label.matrix = [1, 0, 0, 1, 100, 200];
		var full = new AnimateDocumentTextRecord();
		full.fontID = 4;
		full.color = 0xFFFFFF;
		full.offset = [20, 40];
		full.fontHeight = 240;
		full.advances = [600, 550];
		full.glyphs = [0, 2];
		var bare = new AnimateDocumentTextRecord();
		bare.fontHeight = 240;
		bare.advances = [];
		bare.glyphs = [];
		label.records = [full, bare];
		document.symbols.set(6, label);

		var clip = new AnimateDocumentSprite();
		clip.id = 7;
		clip.className = "clips.Clip";
		clip.baseClassName = "flash.display.MovieClip";
		clip.scale9Grid = [20, 20, 1960, 1960];
		var first = new AnimateDocumentFrame();
		first.labels = ["start", "intro"];
		first.scriptSource = "this.stop();";
		var place = new AnimateDocumentFrameObject();
		place.type = CREATE;
		place.id = 1;
		place.symbol = 3;
		place.name = "rect";
		place.matrix = [1, 0, 0, 1, 100, 200];
		place.colorTransform = [20, 20, 20, 10, 0, 0, 0, -100];
		place.filters = [
			[AnimateFilterType.BLUR, 4, 4, 1],
			[AnimateFilterType.COLOR_MATRIX, [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0.5, 0]],
			[AnimateFilterType.DROP_SHADOW, 4, 45, 0, 0.5, 4, 4, 1, 1, false, false, false],
			[AnimateFilterType.GLOW, 0xFF0000, 0.8, 6, 6, 2, 2, true, false],
			[
				AnimateFilterType.GRADIENT_GLOW, 4, 45, [0xFFFFFF, 0xFF0000], [0, 1], [0, 255], 8, 8, 1.5, 1, (BitmapFilterType.OUTER : String), false
			],
			[
				AnimateFilterType.GRADIENT_BEVEL, 2, 135, [0xFFFFFF, 0x000000, 0x000000], [1, 0, 0.75], [0, 128, 255], 3, 3, 1, 2,
				(BitmapFilterType.INNER : String), true
			]
		];
		place.depth = 1;
		place.clipDepth = 0;
		place.visible = true;
		place.blendMode = "multiply";
		place.cacheAsBitmap = true;
		place.metaData = {name: "rect", tags: ["a", "b"], nested: {depth: 1, on: true}};
		var placeBitmap = new AnimateDocumentFrameObject();
		placeBitmap.type = CREATE;
		placeBitmap.id = 2;
		placeBitmap.symbol = 1;
		placeBitmap.depth = 2;
		placeBitmap.clipDepth = 3;
		placeBitmap.visible = true;
		first.objects = [place, placeBitmap];
		var second = new AnimateDocumentFrame();
		var move = new AnimateDocumentFrameObject();
		move.type = UPDATE;
		move.id = 1;
		move.symbol = 3;
		move.name = "rect";
		move.matrix = [0.5, 0.25, -0.25, 0.5, 120, 240];
		move.depth = 1;
		move.clipDepth = 0;
		var remove = new AnimateDocumentFrameObject();
		remove.type = DESTROY;
		remove.id = 2;
		second.objects = [move, remove];
		clip.frames = [first, second, new AnimateDocumentFrame()];
		document.symbols.set(7, clip);

		var button = new AnimateDocumentButton();
		button.id = 8;
		button.className = "ui.Button";
		var state = new AnimateDocumentSprite();
		var stateFrame = new AnimateDocumentFrame();
		var hit = new AnimateDocumentFrameObject();
		hit.type = CREATE;
		hit.symbol = 3;
		hit.id = 0;
		hit.matrix = [1, 0, 0, 1, 0, 0];
		hit.blendMode = "normal";
		hit.depth = 0;
		hit.clipDepth = 0;
		hit.visible = true;
		stateFrame.objects = [hit];
		state.frames = [stateFrame];
		button.upState = state;
		button.overState = state;
		button.hitState = state; // downState stays null
		document.symbols.set(8, button);

		var root = new AnimateDocumentSprite();
		root.className = "Root"; // no id, like the main timeline
		var rootFrame = new AnimateDocumentFrame();
		var placeClip = new AnimateDocumentFrameObject();
		placeClip.type = CREATE;
		placeClip.id = 1;
		placeClip.symbol = 7;
		placeClip.depth = 1;
		placeClip.clipDepth = 0;
		placeClip.visible = true;
		rootFrame.objects = [placeClip];
		root.frames = [rootFrame];
		document.root = root;

		return document;
	}
}

/**
	Structural comparison of symbol graphs: class instances by their fields, anonymous objects by theirs,
	arrays element by element, enums by constructor and parameters, numbers by value. Returns a path to
	the first difference, or null.

	Floats are compared to one part in 10^12: the JSON bundle prints them with 15 significant digits,
	so a number that went through it can differ from the exact double of the binary bundle in its last
	bit (0.447058823529412 both ways, for instance).
**/
class SymbolCompare
{
	// runtime state the library fills in later, not part of the data
	static var IGNORED = ["library", "rendered"];
	static inline var RELATIVE_EPSILON = 1e-12;

	public static function difference(a:Dynamic, b:Dynamic, path:String):String
	{
		if (a == null || b == null)
		{
			return a == b ? null : '$path: $a vs $b';
		}
		if (Reflect.isEnumValue(a))
		{
			if (!Reflect.isEnumValue(b) || Type.enumConstructor(a) != Type.enumConstructor(b)) return '$path: $a vs $b';
			return differenceOfLists(Type.enumParameters(a), Type.enumParameters(b), path + "." + Type.enumConstructor(a));
		}
		return switch (Type.typeof(a))
		{
			case TInt, TFloat:
				var x:Float = a, y:Float = b;
				Math.abs(x - y) <= RELATIVE_EPSILON * Math.max(1, Math.abs(x)) ? null : '$path: $a vs $b';
			case TBool:
				(a : Bool) == (b : Bool) ? null : '$path: $a vs $b';
			case TClass(String):
				(a : String) == (b : String) ? null : '$path: $a vs $b';
			case TClass(Array):
				differenceOfLists(a, b, path);
			case TClass(c):
				if (Type.getClass(b) != c) return '$path: ${Type.getClassName(c)} vs ${Type.getClassName(Type.getClass(b))}';
				for (field in Type.getInstanceFields(c))
				{
					if (IGNORED.indexOf(field) > -1 || Reflect.isFunction(Reflect.field(a, field))) continue;
					var d = difference(Reflect.field(a, field), Reflect.field(b, field), path + "." + field);
					if (d != null) return d;
				}
				null;
			case TObject:
				var fields = Reflect.fields(a);
				for (field in Reflect.fields(b))
					if (fields.indexOf(field) < 0) fields.push(field);
				for (field in fields)
				{
					var d = difference(Reflect.field(a, field), Reflect.field(b, field), path + "." + field);
					if (d != null) return d;
				}
				null;
			default:
				Std.string(a) == Std.string(b) ? null : '$path: $a vs $b';
		}
	}

	static function differenceOfLists(a:Array<Dynamic>, b:Array<Dynamic>, path:String):String
	{
		if (!#if (haxe_ver >= 4.2) Std.isOfType #else Std.is #end (b, Array)) return '$path: array vs $b';
		if (a.length != b.length) return '$path: ${a.length} items vs ${b.length}';
		for (i in 0...a.length)
		{
			var d = difference(a[i], b[i], '$path[$i]');
			if (d != null) return d;
		}
		return null;
	}
}
