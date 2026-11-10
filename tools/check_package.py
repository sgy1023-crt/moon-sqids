"""Package MoonSqids and test its public API from an independent module."""

from pathlib import Path
import subprocess
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
TIMEOUT_SECONDS = 60


def moon(cwd, *args):
    subprocess.run(["moon", *args], cwd=cwd, check=True, timeout=TIMEOUT_SECONDS)


def main():
    with tempfile.TemporaryDirectory(prefix="moonsqids-consumer-") as directory:
        workspace = Path(directory)
        build = workspace / "build"
        moon(ROOT, "package", "--target-dir", str(build))
        archives = list((build / "publish").glob("*.zip"))
        if len(archives) != 1:
            raise RuntimeError(f"expected one module archive, found {archives}")

        library = workspace / "library"
        with zipfile.ZipFile(archives[0]) as archive:
            entries = set(archive.namelist())
            required = {"moon.mod", "moon.pkg", "sqids.mbt", "default_blocklist.mbt",
                        "README.md", "LICENSE", "NOTICE.md"}
            if missing := required - entries:
                raise RuntimeError(f"package is missing {sorted(missing)}")
            if any("node_modules" in Path(entry).parts for entry in entries):
                raise RuntimeError("package contains development dependencies")
            archive.extractall(library)

        consumer = workspace / "consumer"
        consumer.mkdir()
        (workspace / "moon.work").write_text(
            'members = ["consumer", "library"]\n', encoding="utf-8"
        )
        (consumer / "moon.mod").write_text(
            'name = "smoke/consumer"\nimport { "sgy/moon-sqids@0.1.0" }\n',
            encoding="utf-8",
        )
        (consumer / "moon.pkg").write_text(
            'import { "sgy/moon-sqids" @sqids } for "test"\n',
            encoding="utf-8",
        )
        (consumer / "consumer_test.mbt").write_text(
            """test "external module can use the packaged public API" {
  let codec = @sqids.Sqids::new()
  let numbers = [12345L]
  let id = codec.encode(numbers)
  assert_eq(id, "A6da")
  assert_eq(codec.decode(id), numbers)
  assert_eq(codec.encode([4572721L]), "JExTR")
  let custom = @sqids.Sqids::new(min_length=10, blocklist=["86Rf07"])
  assert_eq(custom.decode(custom.encode([1L, 2L, 3L])), [1L, 2L, 3L])
}
""",
            encoding="utf-8",
        )
        for target in ("native", "js"):
            moon(consumer, "test", "-p", "smoke/consumer", "--target", target, "--deny-warn")
        print(f"Verified {archives[0].name} from an independent Native and JS consumer.")


if __name__ == "__main__":
    main()
