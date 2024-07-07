module ninepee.utils;

public static isValid9PString(string str)
{
	foreach(char c; str)
	{
		if(c == 0)
		{
			return false;
		}
	}

	return true;
}
