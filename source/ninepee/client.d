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

private bool buildMessage(State state, ref Message mOut)
{
	// parse size (LE-encoded)
	uint size = order(bytesToIntegral!(uint)(state.sizeBytes), Order.LE);


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


	public void reset()
	{
		this.hasSizeSet = false;
		this.sizeBytes = [];
	}
}

alias MessageHandler = void delegate(Message);

public struct Client
{

	private Buff buff;
	private State state;

	private MessageHandler handler;

	public size_t req(Message message)
	{
		// TODO: Bail out in case that isRequest is false

		
		
		// TODO: Check 
		// if `inBuff` empty, then clean slate
		return 0;
	}

	public size_t recv(ubyte[] input)
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
				return rem;
			}
		}

		// FIXME: Add remaining decodes here

		// TODO: Now take this.state and build message from it
		Message msg;
		bool s = buildMessage(this.state, msg); // TODO: handle status

		// TODO: Dependent on said mesage handle it in different ways
		handleMessage(msg);

		// Reset all state now
		reset();

		return 0;
		
	}

	// Handles the message, such as doing state,
	// waking up something waiting perhaps
	// etc.
	private void handleMessage(Message msg)
	{
		if(handler)
		{
			handler(msg);
		}
		else
		{
			writeln("handleMessage: No handler attached");
		}
	}

	public void reset()
	{
		// Reset client state
		this.state.reset();

		// Reset buffer
		this.buff.reset();
	}

	// TODO: SHould be protected with mutex as delegate is multi-field
	public void setHandler(MessageHandler handler)
	{
		this.handler = handler;
	}
}

version(unittest)
{
	import std.functional : toDelegate;
	
	public void handler(Message msg)
	{
		writeln("handleMessage: ", msg, " (size: ", msg.getPayloadSize(), ")");
	}
}

unittest
{
	Client c;

	c.setHandler(toDelegate(&handler));
	
	assert(c.recv([]) == 4);
	assert(c.recv([0]) == 3);
	assert(c.recv([1,0,0]) == 0);

	assert(c.recv([]) == 4);
	assert(c.recv([255]) == 3);
	assert(c.recv([0,0,0]) == 0);

	
}
