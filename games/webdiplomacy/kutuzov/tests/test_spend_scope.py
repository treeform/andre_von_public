"""Keep retried games out of the current seat's spend summary."""

import importlib.util
from pathlib import Path
import tempfile


def main():
    """Check both telemetry queries and fail before SQL without a job."""
    path = Path(__file__).resolve().parents[1] / 'tools' / 'hosted.py'
    spec = importlib.util.spec_from_file_location('hosted', path)
    hosted = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(hosted)
    queries = []

    def sql(directory, name, query):
        """Return empty telemetry while checking exact current-job scope."""
        queries.append(query)
        assert "a.request_metadata->>'episode_request_id' = '" in query
        assert ("a.request_metadata->>'job_request_id' = "
                "'a9d2d8cf-4887-4575-ab78-6d817967a00c'") in query
        assert "a.timestamp >= '2026-10-16T17:45:49+00:00'" in query
        return []

    hosted.sql = sql
    episode = {
        'id': 'ereq_9e767f87-f881-4162-bc29-b739c1638256',
        'job_id': 'a9d2d8cf-4887-4575-ab78-6d817967a00c',
        'created_at': '2026-10-15T17:03:44Z',
        'dispatched_at': '2026-10-16T17:45:49Z',
        'participants': [{'position': i, 'policy_name': 'fixture',
                          'version': 112} for i in range(7)]}
    with tempfile.TemporaryDirectory() as directory:
        directory = Path(directory)
        result = hosted.spend(directory, episode, quiet=True)
        assert len(queries) == 2
        assert all(not seat['telemetry_present'] for seat in result)
        saved = hosted.read(directory / 'spend-summary.json')
        assert saved['job_request_id'] == episode['job_id']
        assert saved['billing_scope'] == 'current_job_attempt'
        episode['job_id'] = None
        try:
            hosted.spend(directory, episode, quiet=True)
        except hosted.HostedError as error:
            assert 'until a job is assigned' in str(error)
        else:
            raise AssertionError('An unidentified job must not combine attempts.')
        assert len(queries) == 2
    print('Current-job spend scope checks passed without network calls.')


if __name__ == '__main__':
    main()
