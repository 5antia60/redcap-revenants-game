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
            // Templates Windows são GUI; somente o launcher console oferece stdout confiável.
            if (mode == "windows_debug_x86_64" || mode == "windows_release_x86_64") return 0;
            bool wrongTemplate = mode == "windows_debug_x86_64_console" &&
                Environment.GetEnvironmentVariable("RR_TEST_TEMPLATE_WRONG") == "1";
            Console.WriteLine(mode == "wrong_version" || wrongTemplate ? "4.6.0.stable.official.test" :
                mode == "extra_version" ? "4.7.2.stable.official.ed1daf0bf.extra" :
                "4.7.2.stable.official.ed1daf0bf");
            return mode == "version_exit7" ? 7 : 0;
        }
        string project = Environment.GetEnvironmentVariable("RR_TEST_PROJECT_ROOT");
        if (args.Length == 6 && args[0] == "--headless" && args[1] == "--path" &&
            args[2] == project && (args[3] == "--export-debug" || args[3] == "--export-release") &&
            args[4] == "Windows S0")
        {
            bool release = args[3] == "--export-release";
            string expected = Path.Combine(project, release ? "builds/windows-release/foundation.exe" :
                "builds/windows-debug/foundation.exe");
            if (Path.GetFullPath(args[5]) != Path.GetFullPath(expected) ||
                !Directory.Exists(Path.GetDirectoryName(expected)))
                return 23;
            Console.WriteLine("Fixture: argumentos literais corretos");
            if (mode == "exit7") return 7;
            if (mode == "no_artifacts") return 0;
            File.WriteAllText(expected, mode == "empty_exe" ? "" : "fixture EXE");
            if (mode != "exe_only")
                File.WriteAllText(Path.ChangeExtension(expected, ".pck"), mode == "empty_pck" ? "" : "fixture PCK");
            return 0;
        }
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
