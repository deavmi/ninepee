module ninepee.client;


import ninepee.message : Message, isRequest, isReply, MType;
import ninepee.message;

import std.stdio;


private struct Buff
{
	ubyte[] data;
	size_t pos;

	// add more bytes, don't move pointer
	public void tack(ubyte[] input)
	{
		this.data ~= input;
	}

	// requests `reqAmount` bytes. If that many
	// bytes is not yet available then we return
	// the remaining number of bytes needed
	// else we return the `0` (as it was fulfilled)
	// and set the bytes in `output`, we then
	// increment the position by `amount` bytes
	public size_t tryGet(size_t reqAmount, ref ubyte[] output)
	{
		alias req = reqAmount;
		alias buffer = data;
		
		// req=3, pos=0
		// [ 0 0 0 0 ]

		// req=3, pos=1
		// [ 0 0 0 0 ]

		// req=3, pos=2
		// [ 0 0 0 0 ]

		// is req <= buffer.length-pos

		// We have the amount available
		if(req <= buffer.length-pos)
		{
			output = buffer[pos..pos+req];
			pos += req;
			return 0;
		}
		// we need more still
		else
		{
			return req-(buffer.length-pos);
		}	
	}

	public void reset()
	{
		this.data = [];
		this.pos = 0;
	}

	// TODO: take amount
	// public ubyte[] take()
	// {
		
	// }
}

import niknaks.bits;
import std.string : format;
import niknaks.debugging;


// TODO: Move this into ninepee.message
private bool buildMessage(State state, ref Message mOut)
{
	// parse size (LE-encoded)
	uint size = order(bytesToIntegral!(uint)(state.sizeBytes), Order.LE);
	writeln("size: ", size);

	// obtain type after validation check
	if(!isValidType(state.typeByte))
	{
		writeln(format("Unsupported type byte '%d'", state.typeByte));
		return false;
	}
	MType type = cast(MType)state.typeByte;
	writeln("type: ", type);
	
	// obtain tag
	Tag tag = order(bytesToIntegral!(Tag)(state.tagBytes), Order.LE);
	writeln("tag: ", tag);


	// Parse specific kind-of message
	size_t nxtIdx;
	bool goodMesg = false;
	Message mesgO;
	switch(type)
	{
		case MType.Tversion:
		    // msize
		    uint msize = order(bytesToIntegral!(uint)(state.payloadBytes[0..4]), Order.LE);


			writeln(format("leftover food: %d", state.payloadBytes.length-4));
		    
		    // version
		    string ver = obtainString(state.payloadBytes[4..$], nxtIdx);
		    writeln("ver: ", ver);
		    
			mesgO = VersionMessage_V2.makeRequest(msize, ver);
			goodMesg = true;
			break;
		case MType.Rversion:
			// TODO; Finish decode
			writeln("fok");
			break;
		case MType.Tattach:
			// fid
			uint fid = order(bytesToIntegral!(uint)(state.payloadBytes[0..4]), Order.LE);

			// afid
			uint afid = order(bytesToIntegral!(uint)(state.payloadBytes[4..8]), Order.LE);

			writeln(format("fid: %d", fid));
			writeln(format("afid: %d", afid));

			// uname
			string uname = obtainString(state.payloadBytes[8..$], nxtIdx);

			// aname
			string aname = obtainString(state.payloadBytes[8+nxtIdx..$], nxtIdx);

			writeln(format("uname: %s", uname));
			writeln(format("aname: %s", aname));

			mesgO = AttachMessage.makeRequest(fid, afid, uname, aname);
			goodMesg = true;
			break;
		default:
			writeln(format("No support for decoding message of type '%s'", type));
			goodMesg = false;
	}

	// finish up
	if(goodMesg)
	{
		// Set tag
		mesgO.setTag(tag);

		mOut = mesgO;

		return true;
	}
	
	class TestMesg : Message
	{
		private ubyte[] big;
		this(size_t amount)
		{
			super(MType.Twrite);

			for(size_t s = 0; s < amount; s++)
			{
				big ~= 0;
			}
		}

		override ubyte[] getPayload()
		{
			return this.big;
		}
	}
	// TODO: Actually parse shit
	mOut = new TestMesg(size);

	return true;
	
}

private struct State
{
	bool hasSizeSet = false;
	ubyte[] sizeBytes;

	public void setSizeBytes(ubyte[] sizeBytes)
	{
		this.hasSizeSet = true;
		this.sizeBytes = sizeBytes;
	}

	public bool isSizeComplete()
	{
		return this.hasSizeSet;
	}

	bool hasTypeSet = false;
	ubyte typeByte;

	public void setTypeByte(ubyte typeByte)
	{
		this.hasTypeSet = true;
		this.typeByte = typeByte;
	}
	
	public bool isTypeComplete()
	{
		return this.hasTypeSet;
	}

	bool hasTagSet = false;
	ubyte[] tagBytes;

	public void setTagBytes(ubyte[] tagBytes)
	{
		this.hasTagSet = true;
		this.tagBytes = tagBytes;
	}

	public bool isTagComplete()
	{
		return this.hasTagSet;
	}

	public bool isDone()
	{
		return isSizeComplete() &&
			   isTypeComplete() &&
			   isTagComplete() &&
			   isPayloadComplete();
	}

	bool hasPayloadSet = false;
	ubyte[] payloadBytes;

	public void setPayloadBytes(ubyte[] payloadBytes)
	{
		this.hasPayloadSet = true;
		this.payloadBytes = payloadBytes;
	}

	public bool isPayloadComplete()
	{
		return this.hasPayloadSet;
	}

	public void reset()
	{
		this.hasSizeSet = false;
		this.sizeBytes = [];

		this.hasTypeSet = false;
		this.typeByte = 0;

		this.hasTagSet = false;
		this.tagBytes = [];

		this.hasPayloadSet = false;
		this.payloadBytes = [];
	}
}

alias MessageHandler = void delegate(Message);

public enum ParseStatus
{
	NEEDS_MORE_DATA,
	OKAY,
	BAD_MESSAGE
}

private union Obj
{
	size_t remaining;
	Message message;
	string protocolError;
}

public struct ParseResult
{
	private ParseStatus status;
	private Obj obj;

	// @disable
	// this();

	this(size_t remaining)
	{
		this.status = ParseStatus.NEEDS_MORE_DATA;
		this.obj.remaining = remaining;
	}

	this(Message message)
	{
		this.status = ParseStatus.OKAY;
		this.obj.message = message;
	}

	this(string protocolError)
	{
		this.status = ParseStatus.BAD_MESSAGE;
		this.obj.protocolError = protocolError;
	}

	public ParseStatus getStatus()
	{
		return this.status;
	}

	// TODO: Do optionals here to prevent returning invalid results
	public size_t getRemaining()
	{
		return this.obj.remaining;
	}
	
	// TODO: Do optionals here to prevent returning invalid results
	public Message getMessage()
	{
		return this.obj.message;
	}
	
}

public struct Client
{

	private Buff buff;
	private State state;


	public size_t req(Message message)
	{
		// TODO: Bail out in case that isRequest is false

		
		
		// TODO: Check 
		// if `inBuff` empty, then clean slate
		return 0;
	}
	
	public ParseResult recv(ubyte[] input)
	{
		// insert available bytes
		this.buff.tack(input);
		
		// do we have size[4] fulfilled?
		if(!state.isSizeComplete())
		{
			// try get four bytes
			ubyte[] o;
			size_t rem = this.buff.tryGet(4, o); // TODO: rem not needed, if array is updated that says enough

			// then we got 4 bytes, and can set them
			if(rem == 0)
			{
				this.state.setSizeBytes(o);
			}
			// else, not yet and return remaining bytes
			// required
			else
			{
				return ParseResult(rem);
			}
		}

		// do we have type fulfilled?
		if(!state.isTypeComplete())
		{
			// try to get a single byte
			ubyte[] o;
			size_t rem = this.buff.tryGet(1, o);

			// then we got 1 byte, and can set it
			if(rem == 0)
			{
				this.state.setTypeByte(o[0]);
			}
			// else, not yet, return remaining bytes
			else
			{
				return ParseResult(rem);
			}
		}

		// do we have tag fulfilled?
		if(!state.isTagComplete())
		{
			// try to get a two bytes
			ubyte[] o;
			size_t rem = this.buff.tryGet(2, o);

			// then we got 2 byte, and can set it
			if(rem == 0)
			{
				this.state.setTagBytes(o);
			}
			// else, not yet, return remaining bytes
			else
			{
				return ParseResult(rem);
			}
		}

		// calculate the remaining bytes needed
		uint payloadSz = order(bytesToIntegral!(uint)(state.sizeBytes), Order.LE)-(4+1+2);
		writeln("payload bytes expected: ", payloadSz);

		if(!state.isPayloadComplete())
		{
			// try to get `payloadSz` bytes
			ubyte[] o;
			size_t rem = this.buff.tryGet(payloadSz, o);

			// then we got `payloadSz`-many bytes
			if(rem == 0)
			{
				this.state.setPayloadBytes(o);
			}
			// else, not yet, return remaining bytes
			else
			{
				return ParseResult(rem);
			}
		}

		// FIXME: Add remaining decodes here

		// TODO: Now take this.state and build message from it
		Message msg;
		string err;
		parseMessage(this.state, msg, err); // TODO: handle result

		// Reset all state now
		reset();

		// TODO: We could actually make the user then call
		// ... parse()? idk so this signals that you are
		// ... done reading (from whatever your source is
		// ... that is calling this method and filling it
		// ... up with bytes) and we have state available
		// ... for a message
		return ParseResult(msg);
		
	}

	// TODO: USe result type here when doing decode
	// (TODO: not bool and message out, or string out)
	private static bool parseMessage(State state, ref Message m_out, ref string e_out)
	{
		// always parse fine (TODO: not for ever)
		buildMessage(state, m_out);
		return true;
	}


	public void reset()
	{
		// Reset client state
		this.state.reset();

		// Reset buffer
		this.buff.reset();
	}

}

version(unittest)
{
	import std.functional : toDelegate;
	
	public void handler(Message msg)
	{
		writeln("handleMessage: ", msg, " (size: ", msg.getPayloadSize(), ")");
	}

	// TOOD: make niknaks?
	public ubyte[] fakeLoad(size_t sz, ubyte v)
	{
		ubyte[] b;
		for(size_t i = 0; i < sz; i++)
		{
			b ~= v;
		}
		return b;
	}
}

/**
 * First test sets poyload size to 256-(4+1+2) bytes
 * Second test sets payload size to 255-(4+1+2) bytes
 */
unittest
{
	Client c;

	// c.setHandler(toDelegate(&handler));

	// Push data in
	ParseResult res = c.recv([]);
	assert(res.getStatus() == ParseStatus.NEEDS_MORE_DATA);
	assert(res.getRemaining() == 4);

	res = c.recv([0]);
	assert(res.getStatus() == ParseStatus.NEEDS_MORE_DATA);
	assert(res.getRemaining() == 3);

	res = c.recv([1,0,0]);
	assert(res.getStatus() == ParseStatus.NEEDS_MORE_DATA);
	assert(res.getRemaining() == 1);

	res = c.recv([MType.Tversion]);
	assert(res.getStatus() == ParseStatus.NEEDS_MORE_DATA);
	assert(res.getRemaining() == 2);
	
	res = c.recv([1,0]);
	assert(res.getStatus() == ParseStatus.NEEDS_MORE_DATA);
	assert(res.getRemaining() == 256-(4+1+2));

	// construct payload with AAAAAA....
	ubyte[] dummyPayload = fakeLoad(256-(4+1+2), 65);
	res = c.recv(dummyPayload);
	assert(res.getStatus() == ParseStatus.OKAY);
	

	Message m_out = res.getMessage();
	assert(!(m_out is null));
	writeln(m_out);
	handler(m_out);


	// Push data in (again)
	res = c.recv([]);
	assert(res.getStatus() == ParseStatus.NEEDS_MORE_DATA);
	assert(res.getRemaining() == 4);

	res = c.recv([255]);
	assert(res.getStatus() == ParseStatus.NEEDS_MORE_DATA);
	assert(res.getRemaining() == 3);

	res = c.recv([0,0,0]);
	assert(res.getStatus() == ParseStatus.NEEDS_MORE_DATA);
	assert(res.getRemaining() == 1);

	res = c.recv([MType.Rversion]);
	assert(res.getStatus() == ParseStatus.NEEDS_MORE_DATA);
	assert(res.getRemaining() == 2);

	res = c.recv([2,0]);
	assert(res.getStatus() == ParseStatus.NEEDS_MORE_DATA);
	assert(res.getRemaining() == 255-(4+1+2));
	
	// construct payload with BBBBBBB...
	dummyPayload = fakeLoad(256-(4+1+2), 66);
	res = c.recv(dummyPayload);
	assert(res.getStatus() == ParseStatus.OKAY);


	m_out = res.getMessage();
	assert(!(m_out is null));
	writeln(m_out);
	handler(m_out);
}
