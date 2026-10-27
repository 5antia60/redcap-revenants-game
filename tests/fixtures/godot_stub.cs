// Executável controlado exclusivo dos testes de processo dos wrappers.
using System;
using System.IO;

public static class GodotStub
{
    public static int Main(string[] args)
    {
        string mode = Path.GetFileNameWithoutExtension(Environment.GetCommandLineArgs()[0]);
        if (args.Length == 1 && args[0] == "--version")
        {
            Console.WriteLine(mode == "wrong_version" ? "4.6.0.stable.official.test" :
                mode == "extra_version" ? "4.7.2.stable.official.ed1daf0bf.extra" :
                "4.7.2.stable.official.ed1daf0bf");
            return mode == "version_exit7" ? 7 : 0;
        }
        string project = Environment.GetEnvironmentVariable("RR_TEST_PROJECT_ROOT");
        bool run = args.Length == 2 && args[0] == "--path" && args[1] == project;
        bool import = args.Length == 4 && args[0] == "--headless" &&
            args[1] == "--path" && args[2] == project && args[3] == "--import";
        bool test = (args.Length == 5 || args.Length == 7) && args[0] == "--headless" &&
            args[1] == "--path" && args[2] == project && args[3] == "--script" &&
            args[4] == "res://tests/run_tests.gd";
        bool negative = test && args.Length == 7 && args[5] == "--" && args[6] == "--self-test-failure";
        if (!(run || import || (test && (args.Length == 5 || negative))))
        {
            Console.Error.WriteLine("Fixture: argumentos incorretos");
            return 23;
        }
        Console.WriteLine("Fixture: argumentos literais corretos");
        return mode == "exit7" ? 7 : negative ? 1 : 0;
    }
}
