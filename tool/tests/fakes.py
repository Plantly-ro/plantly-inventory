"""A minimal stand-in for the googleapiclient `androidpublisher` service.

Records every `<resource>.<method>(**kwargs)` call as it is executed and
returns canned results, so the scripts' request bodies can be asserted
without network access or the google client libraries.
"""


class FakeRequest:
    def __init__(self, recorder, name, kwargs, result):
        self._recorder = recorder
        self._name = name
        self._kwargs = kwargs
        self._result = result

    def execute(self, num_retries=0):
        self._recorder.append((self._name, self._kwargs))
        if isinstance(self._result, Exception):
            raise self._result
        return self._result


NESTED = ("listings", "images", "bundles", "tracks")


class FakeResource:
    def __init__(self, recorder, results, prefix=""):
        self._recorder = recorder
        self._results = results
        self._prefix = prefix

    def __getattr__(self, name):
        full = f"{self._prefix}{name}"

        def method(**kwargs):
            if name in NESTED:
                return FakeResource(self._recorder, self._results, prefix=f"{full}.")
            result = self._results.get(full)
            if isinstance(result, list):  # per-call sequence; the last entry repeats
                result = result.pop(0) if len(result) > 1 else result[0]
            return FakeRequest(self._recorder, full, kwargs, result)

        return method


class FakeService:
    """`FakeService(results={"edits.insert": {"id": "e1"}, ...})`."""

    def __init__(self, results=None):
        self.calls = []
        self._results = {
            "edits.insert": {"id": "edit-1"},
            "edits.commit": {"id": "edit-1"},
            **(results or {}),
        }

    def edits(self):
        return FakeResource(self.calls, self._results, prefix="edits.")

    def names(self):
        return [name for name, _ in self.calls]

    def kwargs(self, name):
        return [kw for n, kw in self.calls if n == name]


def fake_media(path, mimetype, resumable=False):
    return {"path": path, "mimetype": mimetype, "resumable": resumable}
