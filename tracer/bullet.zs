class ActivationLine
{
	private Line l;
	private uint8 side;

	static ActivationLine Create(Line l, uint side)
	{
		let al = new("ActivationLine");
		al.l = l;
		al.side = side;

		return al;
	}

	Line, uint GetLine() const
	{
		return l, side;
	}
}

class BulletTracer : LineTracer
{
	const BLOCKING = Line.ML_BLOCKEVERYTHING | Line.ML_BLOCKPROJECTILE;

	private Actor bullet;
	private Array<ActivationLine> lines;

	static BulletTracer Create(Actor bullet)
	{
		let bt = new("BulletTracer");
		bt.bullet = bullet;

		return bt;
	}

	void Reset()
	{
		lines.Clear();
		results.ffloor = null;
		results.hitType = TRACE_HitNone;
		results.hitActor = null;
		results.hitLine = null;
	}

	override ETraceStatus TraceCallback()
	{
		switch (results.hitType)
		{
			case TRACE_HitWall:
				if (results.tier == TIER_Middle
					&& (results.hitLine.flags & Line.ML_TWOSIDED)
					&& !(results.hitLine.flags & BLOCKING))
				{
					if (results.hitLine.special && (results.hitLine.activation & SPAC_PCross))
						lines.Push(ActivationLine.Create(results.hitLine, results.side));

					break;
				}
			case TRACE_HitFloor:
			case TRACE_HitCeiling:
				if (results.ffloor
					&& (!(results.ffloor.flags & F3DFloor.FF_EXISTS)
						|| !(results.ffloor.flags & F3DFloor.FF_SOLID)
						|| (results.ffloor.flags & F3DFloor.FF_SHOOTTHROUGH)))
				{
					results.ffloor = null;
					break;
				}
				return TRACE_Stop;

			case TRACE_HitActor:
				if (!CheckHit(results.hitActor))
					break;
				return TRACE_Stop;
		}

		results.hitLine = null;
		results.hitActor = null;
		return TRACE_Skip;
	}

	// Note: This isn't a fully complete set of checks
	private bool CheckHit(Actor mo)
	{
		if (!bullet || !mo || mo == bullet || mo == bullet.target)
			return false;

		if (mo.bNonshootable || (!mo.bShootable && !mo.bSolid))
			return false;

		if (mo.bGhost && bullet.bThruGhost)
			return false;

		if (mo.bSpectral && !bullet.bSpectral)
			return false;

		return true;
	}

	int LineCount() const
	{
		return lines.Size();
	}

	Line, uint GetLine(int i) const
	{
		Line l;
		uint s;
		[l, s] = lines[i].GetLine();

		return l, s;
	}
}

class Bullet : Actor
{
	static const double windTab[] = { 5/32., 10/32., 25/32. };

	private transient BulletTracer bt;

	class<Actor> puffType;
	class<Actor> smokeType;
	double smokeDistance; // interval to spawn smoke along path

	property PuffType : puffType;
	property SmokeType : smokeType;
	property SmokeDistance : smokeDistance;

	Default
	{
		Projectile;
		Radius 1;
		Height 2;
		Decal "BulletChip";
		Bullet.PuffType "BulletPuff";
		Bullet.SmokeType "RocketSmokeTrail";
		Bullet.SmokeDistance 64;

		+BLOODSPLATTER
	}

	override void Tick()
	{
		if (IsFrozen())
			return;

		if (!bt)
			bt = BulletTracer.Create(self);

		if (bWindThrust && waterLevel < 2 && !bNoClip)
		{
			int special = curSector.special;
			switch (special)
			{
				case 40: case 41: case 42: // Wind_East
					Thrust(windTab[special-40], 0);
					break;

				case 43: case 44: case 45: // Wind_North
					Thrust(windTab[special-43], 90);
					break;

				case 46: case 47: case 48: // Wind_South
					Thrust(windTab[special-46], 270);
					break;

				case 49: case 50: case 51: // Wind_West
					Thrust(windTab[special-49], 180);
					break;
			}
		}

		if (!(vel ~== (0,0,0)))
		{
			// need these for the smoke spawning
			Vector3 oldPos = pos;
			double oldSpd = vel.Length();
			Vector3 oldDir = vel / oldSpd;

			bt.Reset();
			bool hit = bt.Trace(pos, curSector, oldDir, oldSpd, TRACE_HitSky);
			SetOrigin(bt.results.hitPos, true);
			vel = bt.results.hitVector * oldSpd;
			angle = bt.results.srcAngleFromTarget;

			for (int i = 0; i < bt.LineCount(); ++i)
			{
				Line l;
				uint s;
				[l, s] = bt.GetLine(i);

				l.Activate(self, s, SPAC_PCross);
				if (bDestroyed)
					return;
			}

			if (bMissile && bRocketTrail && smokeType && GetAge() > 0)
			{
				double interval = smokeDistance <= 0 ? default.smokeDistance : smokeDistance;
				for (double i = 0; i < bt.results.distance; i += interval)
					Spawn(smokeType, level.Vec3Offset(oldPos, oldDir*i), ALLOW_REPLACE);
			}

			CheckPortalTransition();
			UpdateWaterLevel();

			if (hit)
			{
				TryMove(pos.xy, 0, true);
				if (bDestroyed)
					return;

				bool hitSky;
				if (bt.results.hitType == TRACE_HasHitSky)
				{
					if (bMissile && !bSkyExplode)
					{
						Destroy();
						return;
					}

					hitSky = true;
					if (bt.results.hitLine)
						bt.results.hitType = TRACE_HitWall;
					else
						bt.results.hitType = oldDir.z > 0 ? TRACE_HitCeiling : TRACE_HitFloor;
				}

				if (bt.results.hitType == TRACE_HitWall || bt.results.hitType == TRACE_HitActor)
				{
					if (bMissile)
					{
						if (bt.results.hitType == TRACE_HitWall)
						{
							SetOrigin(level.Vec2OffsetZ(pos.xy, -vel.xy.Unit()*12, pos.z), true);
							if (bt.results.ffloor)
								Blocking3DFloor = bt.results.ffloor.model;
						}

						if (puffType
							&& (bt.results.hitType == TRACE_HitWall || GetDefaultByType(puffType).bPuffOnActors))
						{
							SpawnPuff(puffType, pos, angle, angle, 3);
						}

						ExplodeMissile(bt.results.hitLine, bt.results.hitActor, hitSky);
						return;
					}

					vel = (0,0,0);
				}
				else if (bt.results.hitType == TRACE_HitFloor)
				{
					SetZ(floorz);
					if (bMissile)
					{
						if (puffType)
							SpawnPuff(puffType, pos, angle, angle, 3);

						if (bt.results.ffloor)
							Blocking3DFloor = bt.results.ffloor.model;

						Destructible.ProjectileHitPlane(self, SECPART_Floor);
						ExplodeMissile(onsky: hitSky);
						return;
					}

					if (vel.z < 0)
						vel.z = 0;
				}
				else if (bt.results.hitType == TRACE_HitCeiling)
				{
					SetZ(ceilingz - height);
					if (bMissile)
					{
						if (puffType)
							SpawnPuff(puffType, pos, angle, angle, 3);

						if (bt.results.ffloor)
							Blocking3DFloor = bt.results.ffloor.model;

						Destructible.ProjectileHitPlane(self, SECPART_Ceiling);
						ExplodeMissile(onsky: hitSky);
						return;
					}

					if (vel.z > 0)
						vel.z = 0;
				}
			}
		}

		if (!bNoGravity && pos.z > floorZ)
			vel.z -= GetGravity();

		if (!CheckNoDelay())
			return;

		if (tics > 0)
			--tics;
		while (!tics)
		{
			if (!SetState(CurState.NextState))
				return;
		}
	}
}