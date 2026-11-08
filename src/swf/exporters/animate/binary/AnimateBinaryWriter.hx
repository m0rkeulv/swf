package swf.exporters.animate.binary;

import haxe.io.Bytes;
import haxe.io.BytesOutput;
import swf.exporters.animate.AnimateShapeCommandType;
import swf.exporters.animate.AnimateSymbolType;
import swf.exporters.animate.document.*;
import swf.exporters.animate.json.AnimateJsonWriter;

/**
	Writes the `data.bin` of an `animate-binary` bundle from the `AnimateDocument` the exporter builds,
	the same document `AnimateJsonWriter` writes as `data.json`, so the two bundles hold the same data;
	`AnimateBinaryReader` turns it back into symbols.

	Layout, little-endian:

	```
	"ANMB", u16 version, f64 frameRate, str uuid, i32 rootIndex, i32 symbolCount,
	symbolCount x (u8 type, i32 bodyLength, body)
	```

	Scalars: `str` is an i32 length (-1 for null) and UTF-8 bytes; `nint`/`nfloat` are a u8 presence
	flag and the number; `nbool` is one u8 (0 absent, 1 false, 2 true); `ints`/`floats` are an i32
	count (-1 for null), a u8 flag and the numbers, each behind a presence byte when the flag says the
	array holds nulls; `value` is a tagged scalar or array (see `TAG_*`) for the operands whose type
	varies. A field that is null is written as absent, so the reader assigns exactly the fields the
	JSON loader would have found.

	Shape commands are an i32 count and one record per command: a u8 opcode (`AnimateShapeCommandType`,
	as the JSON holds it) and typed operands, coordinates as i32 twips.
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

	/** `symbols` in document order, the root first (see `AnimateDocument.symbolList`). **/
	public static function write(frameRate:Float, uuid:String, symbols:Array<AnimateDocumentSymbol>):Bytes
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

	private function symbol(symbol:AnimateDocumentSymbol):Void
	{
		var outer = out;
		out = new BytesOutput();
		out.bigEndian = false;
		nint(symbol.id);
		str(symbol.className);
		switch (symbol.type)
		{
			case BITMAP:
				var bitmap:AnimateDocumentBitmap = cast symbol;
				str(bitmap.path);
				str(bitmap.alpha);
				nbool(bitmap.smooth);
			case BUTTON:
				var button:AnimateDocumentButton = cast symbol;
				for (state in [button.downState, button.hitState, button.overState, button.upState])
				{
					out.writeByte(state != null ? 1 : 0);
					if (state != null)
					{
						nint(state.id);
						str(state.className);
						spriteBody(state);
					}
				}
			case DYNAMIC_TEXT:
				var text:AnimateDocumentDynamicText = cast symbol;
				str(text.align);
				nbool(text.border);
				nint(text.color);
				nint(text.fontHeight);
				nint(text.fontID);
				str(text.fontName);
				nbool(text.html);
				nint(text.indent);
				nbool(text.input);
				nint(text.leading);
				nint(text.leftMargin);
				nbool(text.multiline);
				nbool(text.password);
				nint(text.rightMargin);
				nbool(text.selectable);
				str(text.text);
				nbool(text.wordWrap);
				ints(text.rect);
			case FONT:
				var font:AnimateDocumentFont = cast symbol;
				ints(font.advances);
				nint(font.ascent);
				nbool(font.bold);
				ints(font.codes);
				nint(font.descent);
				nbool(font.italic);
				nint(font.leading);
				str(font.name);
				out.writeInt32(font.glyphs == null ? -1 : font.glyphs.length);
				if (font.glyphs != null)
				{
					for (glyph in font.glyphs)
					{
						out.writeByte(glyph != null ? 1 : 0);
						if (glyph != null) commands(glyph);
					}
				}
			case SHAPE:
				var shape:AnimateDocumentShape = cast symbol;
				commands(shape.commands);
			case SPRITE:
				spriteBody(cast symbol);
			case STATIC_TEXT:
				var text:AnimateDocumentStaticText = cast symbol;
				matrix(text.matrix);
				out.writeInt32(text.records == null ? -1 : text.records.length);
				if (text.records != null)
				{
					for (record in text.records)
					{
						ints(record.advances);
						nint(record.color);
						nint(record.fontHeight);
						nint(record.fontID);
						ints(record.glyphs);
						ints(record.offset);
					}
				}
			default:
				throw "AnimateBinaryWriter: unknown symbol type " + symbol.type;
		}
		var body = out.getBytes();
		out = outer;
		out.writeByte(symbol.type);
		out.writeInt32(body.length);
		out.write(body);
	}

	/** The fields of a sprite after the common id and class name; a button state is one too. **/
	private function spriteBody(sprite:AnimateDocumentSprite):Void
	{
		str(sprite.baseClassName);
		ints(sprite.scale9Grid);
		out.writeInt32(sprite.frames.length);
		for (frame in sprite.frames)
		{
			strs(frame.labels);
			str(frame.scriptSource);
			out.writeInt32(frame.objects == null ? -1 : frame.objects.length);
			if (frame.objects != null)
			{
				for (object in frame.objects)
					frameObject(object);
			}
		}
	}

	private function frameObject(object:AnimateDocumentFrameObject):Void
	{
		nint(object.symbol);
		nint(object.id);
		str(object.name);
		out.writeByte(object.type);
		matrix(object.matrix);
		ints(object.colorTransform);
		out.writeInt32(object.filters == null ? -1 : object.filters.length);
		if (object.filters != null)
		{
			for (filter in object.filters)
				value(filter);
		}
		nint(object.depth);
		nint(object.clipDepth);
		nbool(object.visible);
		str(object.blendMode);
		nbool(object.cacheAsBitmap);
		str(object.metaData != null ? AnimateJsonWriter.value(object.metaData) : null);
	}

	/** The flat token array the document holds, as one record per command. **/
	private function commands(tokens:Array<Dynamic>):Void
	{
		var outer = out;
		out = new BytesOutput();
		out.bigEndian = false;
		var count = 0, i = 0;
		while (i < tokens.length)
		{
			var op:AnimateShapeCommandType = Std.int(tokens[i]);
			out.writeByte(op);
			count++;
			switch (op)
			{
				case BEGIN_BITMAP_FILL: // bitmap, matrix, repeat, smooth
					out.writeInt32(Std.int(tokens[i + 1]));
					matrix(tokens[i + 2]);
					nbool(tokens[i + 3]);
					nbool(tokens[i + 4]);
					i += 5;
				case BEGIN_FILL: // color, alpha
					out.writeInt32(Std.int(tokens[i + 1]));
					out.writeDouble(tokens[i + 2] * 1.0);
					i += 3;
				case BEGIN_GRADIENT_FILL: // type, colors, alphas, ratios, matrix, spread, interpolation, focal point
					value(tokens[i + 1]);
					ints(tokens[i + 2]);
					floats(tokens[i + 3]);
					ints(tokens[i + 4]);
					matrix(tokens[i + 5]);
					value(tokens[i + 6]);
					value(tokens[i + 7]);
					value(tokens[i + 8]);
					i += 9;
				case CLEAR_LINE_STYLE, END_FILL:
					i++;
				case CURVE_TO:
					for (k in 1...5)
						out.writeInt32(Std.int(tokens[i + k]));
					i += 5;
				case LINE_STYLE: // thickness, color, alpha, pixelHinting, scaleMode, caps, joints, miterLimit
					for (k in 1...9)
						value(tokens[i + k]);
					i += 9;
				case LINE_TO, MOVE_TO:
					out.writeInt32(Std.int(tokens[i + 1]));
					out.writeInt32(Std.int(tokens[i + 2]));
					i += 3;
				default:
					throw "AnimateBinaryWriter: unknown shape command " + op;
			}
		}
		var body = out.getBytes();
		out = outer;
		out.writeInt32(count);
		out.write(body);
	}

	// ------------------------------------------------------------------------------------ scalars

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

	private function nint(v:Null<Int>):Void
	{
		out.writeByte(v != null ? 1 : 0);
		if (v != null) out.writeInt32(v);
	}

	private function nbool(v:Null<Bool>):Void
	{
		out.writeByte(v == null ? 0 : (v ? 2 : 1));
	}

	/**
		An int array: the count (-1 for null), a flag, and the numbers; with the flag set, each number is
		preceded by a presence byte, so an array that holds nulls (the advance table of a font does) keeps
		them.
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

	/** [a, b, c, d, tx, ty] as the document holds it: four factors and two twip offsets. **/
	private function matrix(values:Array<Dynamic>):Void
	{
		out.writeByte(values != null ? 1 : 0);
		if (values == null) return;
		for (k in 0...4)
			out.writeDouble(values[k] * 1.0);
		out.writeInt32(Std.int(values[4]));
		out.writeInt32(Std.int(values[5]));
	}

	/** An operand whose type the document does not fix, tagged so the reader gets the same value back. **/
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
			str(AnimateJsonWriter.value(v));
		}
	}
}
