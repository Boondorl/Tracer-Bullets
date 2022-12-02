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
            Vector2 angles = Distribution.Gaussian(2.4);
            //Vector2 angles = Distribution.Uniform(2.4);
            Quat ofs = Quat.FromAngles(angles.x, angles.y, 0);

            Vector3 dir = base * ofs * forward;

            b.target = self;
            b.vel = dir * b.speed;
            b.angle = atan2(dir.y, dir.x);
            b.pitch = -asin(dir.z);
        }
    }
}

class ExampleSuperShotgun : SuperShotgun replaces SuperShotgun
{
    Default
    {
        Weapon.SlotNumber 3;
        AttackSound "weapons/sshotf";
    }

    States
    {
        Fire:
            SHT2 A 7 A_FireNewSuperShotgun;
            SHT2 B 7;
            SHT2 C 7 A_CheckReload;
            SHT2 D 6 A_StartSound("weapons/sshoto", CHAN_WEAPON, CHANF_OVERLAP);
            SHT2 E 6;
            SHT2 F 6 A_StartSound("weapons/sshotl", CHAN_WEAPON, CHANF_OVERLAP);
            SHT2 G 6;
            SHT2 H 5 A_StartSound("weapons/sshotc", CHAN_WEAPON, CHANF_OVERLAP);
            SHT2 A 3;
            Goto Ready;
    }

    action void A_FireNewSuperShotgun()
    {
        A_StartSound(invoker.AttackSound, CHAN_WEAPON, CHANF_OVERLAP);
        A_GunFlash();

        invoker.DepleteAmmo(invoker.bAltFire);

        Vector3 forward = (1, 0, 0);
        Quat base = Quat.FromAngles(angle, pitch, roll);
        Vector3 spawnPos = (pos.xy, player.viewZ);

        for (int i = 0; i < 24; ++i)
        {
            let b = Spawn("ShotgunPellet", spawnPos, ALLOW_REPLACE);
            if (!b)
                continue;

            // conal spread
            Vector2 angles = Distribution.Gaussian(2.4);
            //Vector2 angles = Distribution.Uniform(2.4);

            angles.x *= 2; // wider horizontal spread
            Quat ofs = Quat.FromAngles(angles.x, angles.y, 0);

            Vector3 dir = base * ofs * forward;

            b.target = self;
            b.vel = dir * b.speed;
            b.angle = atan2(dir.y, dir.x);
            b.pitch = -asin(dir.z);
        }
    }
}