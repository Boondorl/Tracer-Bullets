struct Distribution
{
    private static Vector2 CalculateGaussian(double standDev = 1)
	{
		double x, y, s;
		do
		{
			x = FRandom[Gaussian](-1,1);
			y = FRandom[Gaussian](-1,1);
			s = x*x + y*y;
		} while (s >= 1 || !s);
		
		s = sqrt(-2*log(s) / s) * standDev;
		
		return (x,y)*s;
	}
	
	static Vector2 Gaussian(double radius, double deviations = 2)
	{
		double cap = radius * radius;
		double standDev = sqrt(cap*0.5) / deviations;
		
		Vector2 point = CalculateGaussian(standDev);
		if (point.LengthSquared() > cap)
			point = point.Unit() * radius;
		
		return point;
	}

    static Vector2 Uniform(double radius)
    {
        return FRandom[Uniform](0,360).ToVector() * (radius * sqrt(FRandom[Uniform](0,1)));
    }
}