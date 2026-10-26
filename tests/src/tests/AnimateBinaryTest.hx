package tests;

import haxe.Json;
import openfl.utils.Assets;
import swf.exporters.animate.AnimateBinaryReader;
import swf.exporters.animate.AnimateBinaryWriter;
import swf.exporters.animate.AnimateLibrary;
import utest.Assert;
import utest.Test;

/**
	An `animate-binary` bundle must give the same symbols as the `animate` bundle of the same SWF.
	`project.xml` builds both from `fixtures/shapes.swf`; the second test round-trips the JSON document
	through the writer and the reader in memory, so the writer is covered without the build tool.
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
		assertSameSymbols(json, binary.symbols, binary.root);
	}

	public function testWriterRoundTrip():Void
	{
		var json:AnimateLibrary = cast Assets.getLibrary("shapes_json");
		var document:Dynamic = Json.parse(json.getText("data.json"));
		var symbolArray:Array<Dynamic> = document.symbols;
		var bytes = AnimateBinaryWriter.write(document.frameRate, document.uuid, symbolArray);
		var decoded = AnimateBinaryReader.read(bytes);
		Assert.equals(document.frameRate, decoded.frameRate);
		Assert.equals(document.uuid, decoded.uuid);
		Assert.equals(symbolArray.length, decoded.symbols.length);

		var decodedSymbols = new Map();
		for (symbol in decoded.symbols)
			decodedSymbols.set(symbol.id, symbol);
		assertSameSymbols(json, decodedSymbols, cast decoded.symbols[decoded.rootIndex]);
	}

	/** Every symbol of `json` must have an equal counterpart, and the roots must be equal. **/
	private function assertSameSymbols(json:AnimateLibrary, symbols:Map<Int, Dynamic>, root:Dynamic):Void
	{
		var count = 0;
		for (id in json.symbols.keys())
		{
			count++;
			var difference = SymbolCompare.difference(json.symbols.get(id), symbols.get(id), 'symbol $id');
			Assert.isNull(difference, difference);
		}
		var otherCount = 0;
		for (id in symbols.keys())
			otherCount++;
		Assert.equals(count, otherCount);
		Assert.isTrue(count > 1);
		var difference = SymbolCompare.difference(json.root, root, "root");
		Assert.isNull(difference, difference);
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
