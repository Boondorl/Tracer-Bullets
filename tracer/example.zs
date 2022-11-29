class ShotgunPellet : Bullet
{
    Default
    {
        DamageFunction 9;
        Speed 128;
        Scale 0.1;

        +BRIGHT
        +FORCEXYBILLBOARD
    }

    States
    {
        Spawn:
            BAL1 AB 3;
            Loop;

        Death:
            BAL1 CDE 3;
            Stop;
    }
}

class ExampleShotgun : Shotgun replaces Shotgun
{
    Default
    {
        Weapon.SlotNumber 3;
        AttackSound "weapons/shotgf";
    }

    States
    {
        Fire:
            SHTG A 7 A_FireNewShotgun;
            SHTG BC 5;
            SHTG D 4;
            SHTG CB 5;
            SHTG A 4;
            Goto Ready;
    }

    action void A_FireNewShotgun()
    {
        A_StartSound(invoker.AttackSound, CHAN_WEAPON, CHANF_OVERLAP);
        A_GunFlash();

        invoker.DepleteAmmo(invoker.bAltFire);

        Vector3 forward = (1, 0, 0);
        Quat base = Quat.FromAngles(angle, pitch, roll);
        Vector3 spawnPos = (pos.xy, player.viewZ);

        for (int i = 0; i < 9; ++i)
        {
            let b = Spawn("ShotgunPellet", spawnPos, ALLOW_REPLACE);
            if (!b)
                continue;

            // conal spread
            // box-muller is really much better for multi-shot weapons than uniform...
            double theta = FRandom[Gunshot](0,360);
            double rad = 2.4 * sqrt(FRandom[Gunshot](0,1));
            Quat ofs = Quat.FromAngles(rad * cos(theta), rad * sin(theta), 0);

            Vector3 dir = base * ofs * forward;

            b.target = self;
            b.vel = dir * b.speed;
            b.angle = atan2(dir.y, dir.x);
            b.pitch = -asin(dir.z);
        }
    }
}