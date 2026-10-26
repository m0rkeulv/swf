package swf.exporters.animate;

import haxe.Json;
import haxe.io.Bytes;
import haxe.io.BytesOutput;

/**
	Writes the `data.bin` of an `animate-binary` bundle. It takes what the JSON bundle is made from, the
	root sprite and the symbols as the anonymous objects `AnimateLibraryExporter` builds, so the two
	bundles hold the same data; `AnimateBinaryReader` turns it back into symbols.

	Layout, little-endian:

	```
	"ANMB", u16 version, f64 frameRate, str uuid, i32 rootIndex, i32 symbolCount,
	symbolCount x (u8 type, i32 bodyLength, body)
	```

	Scalars: `str` is an i32 length (-1 for null) and UTF-8 bytes; `nint`/`nfloat` are a u8 presence
	flag and the number; `nbool` is one u8 (0 absent, 1 false, 2 true); `ints`/`floats` are an i32
	count (-1 for null), a u8 flag and the numbers, each behind a presence byte when the flag says the
	array holds nulls; `value` is a tagged scalar or array (see `TAG_*`) for the fields whose type
	varies. A field the JSON would leave out is written as absent, so the reader assigns exactly the
	fields `Json.parse` would have provided.

	Shape commands are an i32 count and one record per command: a u8 opcode (the `SWFShapeCommandType`
	numbers the JSON uses) and typed operands, coordinates as i32 twips.
**/
class AnimateBinaryWriter
{
	public static inline var MAGIC = "ANMB";
	public static inline var VERSION = 1;

	public static inline var TAG_NULL = 0;
	public static inline var TAG_FALSE = 1;
	public static inline var TAG_TRUE = 2;
	public static inline var TAG_INT = 3;
	public static inline var TAG_FLOAT = 4;
	public static inline var TAG_STRING = 5;
	public static inline var TAG_ARRAY = 6;
	public static inline var TAG_JSON = 7;

	private var out:BytesOutput;

	/** `symbols` in document order, the root first, as `serialize()` lists them for the JSON. **/
	public static function write(frameRate:Float, uuid:String, symbols:Array<Dynamic>):Bytes
	{
		var writer = new AnimateBinaryWriter();
		var out = writer.out;
		out.writeString(MAGIC);
		out.writeUInt16(VERSION);
		out.writeDouble(frameRate);
		writer.str(uuid);
		out.writeInt32(0);
		out.writeInt32(symbols.length);
		for (symbol in symbols)
			writer.symbol(symbol);
		return out.getBytes();
	}

	private function new()
	{
		out = new BytesOutput();
		out.bigEndian = false;
	}

	// ------------------------------------------------------------------------------------ symbols

	private function symbol(data:Dynamic):Void
	{
		var type = Std.int(field(data, "type"));
		var outer = out;
		out = new BytesOutput();
		out.bigEndian = false;
		nint(field(data, "id"));
		str(field(data, "className"));
		switch (type)
		{
			case 0: // BITMAP
				str(field(data, "path"));
				str(field(data, "alpha"));
				nbool(field(data, "smooth"));
			case 1: // BUTTON
				for (state in ["downState", "hitState", "overState", "upState"])
				{
					var sprite = field(data, state);
					out.writeByte(sprite != null ? 1 : 0);
					if (sprite != null)
					{
						nint(field(sprite, "id"));
						str(field(sprite, "className"));
						spriteBody(sprite);
					}
				}
			case 2: // DYNAMIC_TEXT
				str(field(data, "align"));
				nbool(field(data, "border"));
				nint(field(data, "color"));
				nint(field(data, "fontHeight"));
				nint(field(data, "fontID"));
				str(field(data, "fontName"));
				nbool(field(data, "html"));
				nint(field(data, "indent"));
				nbool(field(data, "input"));
				nint(field(data, "leading"));
				nint(field(data, "leftMargin"));
				nbool(field(data, "multiline"));
				nbool(field(data, "password"));
				nint(field(data, "rightMargin"));
				nbool(field(data, "selectable"));
				str(field(data, "text"));
				nbool(field(data, "wordWrap"));
				ints(field(data, "rect"));
			case 3: // FONT
				ints(field(data, "advances"));
				nint(field(data, "ascent"));
				nbool(field(data, "bold"));
				ints(field(data, "codes"));
				nint(field(data, "descent"));
				nbool(field(data, "italic"));
				nint(field(data, "leading"));
				str(field(data, "name"));
				var glyphs:Array<Array<Dynamic>> = field(data, "glyphs");
				out.writeInt32(glyphs == null ? -1 : glyphs.length);
				if (glyphs != null)
				{
					for (glyph in glyphs)
					{
						out.writeByte(glyph != null ? 1 : 0);
						if (glyph != null) commands(glyph);
					}
				}
			case 4: // SHAPE
				commands(field(data, "commands"));
			case 5: // SPRITE
				spriteBody(data);
			case 6: // STATIC_TEXT
				matrix(field(data, "matrix"));
				var records:Array<Dynamic> = field(data, "records");
				out.writeInt32(records == null ? -1 : records.length);
				if (records != null)
				{
					for (record in records)
					{
						ints(field(record, "advances"));
						nint(field(record, "color"));
						nint(field(record, "fontHeight"));
						nint(field(record, "fontID"));
						ints(field(record, "glyphs"));
						ints(field(record, "offset"));
					}
				}
			default:
				throw 'AnimateBinaryWriter: unknown symbol type $type';
		}
		var body = out.getBytes();
		out = outer;
		out.writeByte(type);
		out.writeInt32(body.length);
		out.write(body);
	}

	/** The fields of a sprite after the common id and class name; a button state is one too. **/
	private function spriteBody(data:Dynamic):Void
	{
		str(field(data, "baseClassName"));
		ints(field(data, "scale9Grid"));
		var frames:Array<Dynamic> = field(data, "frames");
		out.writeInt32(frames.length);
		for (frame in frames)
		{
			strs(field(frame, "labels"));
			str(field(frame, "scriptSource"));
			var objects:Array<Dynamic> = field(frame, "objects");
			out.writeInt32(objects == null ? -1 : objects.length);
			if (objects != null)
			{
				for (object in objects)
					frameObject(object);
			}
		}
	}

	private function frameObject(data:Dynamic):Void
	{
		nint(field(data, "symbol"));
		nint(field(data, "id"));
		str(field(data, "name"));
		out.writeByte(Std.int(field(data, "type")));
		matrix(field(data, "matrix"));
		ints(field(data, "colorTransform"));
		var filters:Array<Dynamic> = field(data, "filters");
		out.writeInt32(filters == null ? -1 : filters.length);
		if (filters != null)
		{
			for (filter in filters)
				value(filter);
		}
		nint(field(data, "depth"));
		nint(field(data, "clipDepth"));
		nbool(field(data, "visible"));
		str(field(data, "blendMode"));
		nbool(field(data, "cacheAsBitmap"));
		var metaData = field(data, "metaData");
		str(metaData != null ? Json.stringify(metaData) : null);
	}

	/** The flat token array the JSON holds, as one record per command. **/
	private function commands(tokens:Array<Dynamic>):Void
	{
		var outer = out;
		out = new BytesOutput();
		out.bigEndian = false;
		var count = 0, i = 0;
		while (i < tokens.length)
		{
			var op = Std.int(tokens[i]);
			out.writeByte(op);
			count++;
			switch (op)
			{
				case 0: // BEGIN_BITMAP_FILL: bitmap, matrix, repeat, smooth
					out.writeInt32(Std.int(tokens[i + 1]));
					matrix(tokens[i + 2]);
					nbool(tokens[i + 3]);
					nbool(tokens[i + 4]);
					i += 5;
				case 1: // BEGIN_FILL: color, alpha
					out.writeInt32(Std.int(tokens[i + 1]));
					out.writeDouble(tokens[i + 2] * 1.0);
					i += 3;
				case 2: // BEGIN_GRADIENT_FILL: type, colors, alphas, ratios, matrix, spread, interpolation, focal point
					value(tokens[i + 1]);
					ints(tokens[i + 2]);
					floats(tokens[i + 3]);
					ints(tokens[i + 4]);
					matrix(tokens[i + 5]);
					value(tokens[i + 6]);
					value(tokens[i + 7]);
					value(tokens[i + 8]);
					i += 9;
				case 3, 5: // CLEAR_LINE_STYLE, END_FILL
					i++;
				case 4: // CURVE_TO
					for (k in 1...5)
						out.writeInt32(Std.int(tokens[i + k]));
					i += 5;
				case 6: // LINE_STYLE: thickness, color, alpha, pixelHinting, scaleMode, caps, joints, miterLimit
					for (k in 1...9)
						value(tokens[i + k]);
					i += 9;
				case 7, 8: // LINE_TO, MOVE_TO
					out.writeInt32(Std.int(tokens[i + 1]));
					out.writeInt32(Std.int(tokens[i + 2]));
					i += 3;
				default:
					throw 'AnimateBinaryWriter: unknown shape command $op';
			}
		}
		var body = out.getBytes();
		out = outer;
		out.writeInt32(count);
		out.write(body);
	}

	// ------------------------------------------------------------------------------------ scalars

	private inline function field(object:Dynamic, name:String):Dynamic
	{
		return Reflect.field(object, name);
	}

	private function str(s:String):Void
	{
		if (s == null)
		{
			out.writeInt32(-1);
			return;
		}
		var bytes = Bytes.ofString(s);
		out.writeInt32(bytes.length);
		out.write(bytes);
	}

	private function strs(list:Array<String>):Void
	{
		out.writeInt32(list == null ? -1 : list.length);
		if (list != null)
		{
			for (s in list)
				str(s);
		}
	}

	private function nint(v:Dynamic):Void
	{
		out.writeByte(v != null ? 1 : 0);
		if (v != null) out.writeInt32(Std.int(v));
	}

	private function nbool(v:Null<Bool>):Void
	{
		out.writeByte(v == null ? 0 : (v ? 2 : 1));
	}

	/**
		An int array: the count (-1 for null), a flag, and the numbers; with the flag set, each number is
		preceded by a presence byte, so an array that holds nulls (a font's code table can) keeps them.
	**/
	private function ints(list:Array<Dynamic>):Void
	{
		out.writeInt32(list == null ? -1 : list.length);
		if (list == null) return;
		var holes = hasNull(list);
		out.writeByte(holes ? 1 : 0);
		for (v in list)
		{
			if (holes) out.writeByte(v == null ? 0 : 1);
			if (v != null) out.writeInt32(Std.int(v));
		}
	}

	/** A float array, stored like `ints`. **/
	private function floats(list:Array<Dynamic>):Void
	{
		out.writeInt32(list == null ? -1 : list.length);
		if (list == null) return;
		var holes = hasNull(list);
		out.writeByte(holes ? 1 : 0);
		for (v in list)
		{
			if (holes) out.writeByte(v == null ? 0 : 1);
			if (v != null) out.writeDouble(v * 1.0);
		}
	}

	private static function hasNull(list:Array<Dynamic>):Bool
	{
		for (v in list)
			if (v == null) return true;
		return false;
	}

	/** [a, b, c, d, tx, ty] as the JSON holds it: four factors and two twip offsets. **/
	private function matrix(values:Array<Dynamic>):Void
	{
		out.writeByte(values != null ? 1 : 0);
		if (values == null) return;
		for (k in 0...4)
			out.writeDouble(values[k] * 1.0);
		out.writeInt32(Std.int(values[4]));
		out.writeInt32(Std.int(values[5]));
	}

	/** A scalar or array whose type the JSON does not fix, tagged so the reader gets the same value back. **/
	private function value(v:Dynamic):Void
	{
		if (v == null)
		{
			out.writeByte(TAG_NULL);
		}
		else if (Std.isOfType(v, Bool))
		{
			out.writeByte(v ? TAG_TRUE : TAG_FALSE);
		}
		else if (Std.isOfType(v, Float))
		{
			// a whole number is an Int, as it is after Json.parse of the JSON bundle (neko also says a
			// whole Float is an Int, so the number itself decides, not its runtime type)
			var f:Float = v * 1.0;
			if (f == Math.ffloor(f) && Math.abs(f) < 2147483648.0)
			{
				out.writeByte(TAG_INT);
				out.writeInt32(Std.int(f));
			}
			else
			{
				out.writeByte(TAG_FLOAT);
				out.writeDouble(f);
			}
		}
		else if (Std.isOfType(v, String))
		{
			out.writeByte(TAG_STRING);
			str(v);
		}
		else if (Std.isOfType(v, Array))
		{
			var list:Array<Dynamic> = v;
			out.writeByte(TAG_ARRAY);
			out.writeInt32(list.length);
			for (item in list)
				value(item);
		}
		else
		{
			out.writeByte(TAG_JSON);
			str(Json.stringify(v));
		}
	}
}
