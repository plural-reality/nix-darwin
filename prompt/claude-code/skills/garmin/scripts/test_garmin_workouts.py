import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("garmin.py")
FAKE_MODULE = '''
class Garmin:
    def login(self):
        return None
    def get_workouts(self, start=0, limit=100):
        return [{"start": start, "limit": limit}]
    def get_workout_by_id(self, workout_id):
        return {"workoutId": int(workout_id)}
    def get_scheduled_workouts(self, year, month):
        return {"year": int(year), "month": int(month)}
    def get_scheduled_workout_by_id(self, schedule_id):
        return {"workoutScheduleId": int(schedule_id)}
    def upload_workout(self, payload):
        return {"created": payload}
    def update_workout(self, workout_id, payload):
        return {"updated": int(workout_id), "payload": payload}
    def schedule_workout(self, workout_id, date):
        return {"scheduled": int(workout_id), "date": date}
    def unschedule_workout(self, schedule_id):
        return {"unscheduled": int(schedule_id)}
    def push_workout_to_device(self, workout_id, device_id):
        return {"pushed": int(workout_id), "deviceId": int(device_id)}
'''


class GarminWorkoutCommandsTest(unittest.TestCase):
    def invoke(self, *args, stdin=""):
        with tempfile.TemporaryDirectory() as root:
            package = Path(root) / "garminconnect"
            package.mkdir()
            (package / "__init__.py").write_text(FAKE_MODULE)
            completed = subprocess.run(
                ["python3", str(SCRIPT), *args],
                input=stdin,
                text=True,
                capture_output=True,
                env={**os.environ, "PYTHONPATH": root, "GARMINTOKENS": root},
                check=False,
            )
            return completed, json.loads(completed.stdout)

    def test_reads_workout_library_through_typed_command(self):
        completed, output = self.invoke("workouts", "5", "20")

        self.assertEqual(completed.returncode, 0)
        self.assertEqual(output, [{"start": 5, "limit": 20}])

    def test_creates_workout_from_stdin_json(self):
        completed, output = self.invoke("workout-create", stdin='{"workoutName":"Codex Bike"}')

        self.assertEqual(completed.returncode, 0)
        self.assertEqual(output, {"created": {"workoutName": "Codex Bike"}})

    def test_schedules_workout_on_explicit_date(self):
        completed, output = self.invoke("workout-schedule", "123", "2026-08-17")

        self.assertEqual(completed.returncode, 0)
        self.assertEqual(output, {"scheduled": 123, "date": "2026-08-17"})

    def test_push_requires_explicit_device(self):
        completed, output = self.invoke("workout-push", "123", "456")

        self.assertEqual(completed.returncode, 0)
        self.assertEqual(output, {"pushed": 123, "deviceId": 456})


if __name__ == "__main__":
    unittest.main()
