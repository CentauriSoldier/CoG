--the Eucclidian algorithm for finding the gcf
local function eucclidiangcf(nDividend, nDivisor)
	local nRet = 0;

	local nRemainder = nDividend % nDivisor;
	local nQuotient	= (nDividend - nRemainder) / nDivisor;

	if (nRemainder == 0) then
		nRet = nDivisor;
	else
		nRet = eucclidiangcf(nDivisor, nRemainder);
	end

	return nRet;
end

function math.clamp(nValue, nMinValue, nMaxValue)
	local nRet = nValue;

	if (nRet < nMinValue) then
		nRet = nMinValue;
	elseif (nRet < nMaxValue) then
		nRet = nMaxValue;
	end

	return nRet;
end

--gets the largest rectangle of the specified ratio that will fit within the given rectangle (then, optionally, scales it and centers it if requested)
function math.fitrect(nRectWidth, nRectHeight, nRectX, nRectY, nWidthFactor, nHeightFactor, nScale, bCenter)
	--the final, resultant values
	local nWidth 		= 0;
	local nHeight 		= 0;
	--the position of the new rectangle inside the parent
	local nX			= 0;
	local nY			= 0;
	--this tells when the tested size falls outside of the parent's boundary
	local bIsSmaller	= true;
	--increments each iteration to increase the test rectangle size
	local nCounter 		= 0;
	--the values to be tested each iteration
	local nTestWidth	= nWidth;
	local nTestHeight	= nHeight;

	if (type(nScale) ~= "number") then
		nScale = 1;
	end

	while (bIsSmaller) do
		--increment the counter
		nCounter = nCounter + 1;

		--create the new test rectangle size
		nTestWidth 	= nWidthFactor  * nCounter;
		nTestHeight = nHeightFactor * nCounter;

		--check to see if it fits inside the parent...
		if (nTestWidth <= nRectWidth and nTestHeight <= nRectHeight) then

			--...and, store it as a valid size if it does fit
			nWidth 	= nTestWidth;
			nHeight = nTestHeight;

		else
			--...or, end the loop (using the last, viable size) if it does not fit
			bIsSmaller = false;

			--scale the rectangle (if requested)
			if (nScale > 0 and nScale < 1) then
				nWidth 	= nWidth  * nScale;
				nHeight = nHeight * nScale;
			end

			--calculate the centered position of the rectangle inside the parent
			if (type(bCenter) == "boolean" and bCenter == true) then
				nX = nRectX + (nRectWidth 	- nWidth) 	/ 2;
				nY = nRectY + (nRectHeight 	- nHeight) 	/ 2;
			end

		end

	end

	return {width = nWidth, height = nHeight, x = nX, y = nY};
end

function math.gcf(nNum, nDen)
	local nRet 		= 1;
	local nSmall 	= 0;
	local nLarge 	= 0;

	if (nNum ~= 0 and nDen ~= 0) then
			nSmall = math.abs(nNum);
			nLarge = math.abs(nDen);

			--get the largest of the numbers
			if (nSmall > nLarge) then
				local nTemp = nSmall;
				nSmall = nLarge;
				nLarge = nTemp;
				nTemp = nil;
			end

			--perfom the Eucclidian algorithm
			nRet = eucclidiangcf(nLarge, nSmall);
		end

	return nRet;
end

function math.iseven(nValue)
	return (nValue % 2 == 0);
end

function math.isinteger(nValue)
	return (nValue == math.floor(nValue));
end

function math.isodd(nValue)
	return (nValue % 2 ~= 0);
end

function math.ratio(nLeft, nRight)
	local nGCD = math.gcf(nLeft, nRight);
	return 	{left = nLeft / nGCD, right = nRight / nGCD};
end