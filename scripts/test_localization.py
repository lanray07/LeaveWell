import unittest
from localization import validate_translation

class TranslationGateTests(unittest.TestCase):
    def entry(self, source='Continue', **kwargs):
        return dict(source=source, translation='Continuar', locale='es', status='reviewed', reviewed=True,
                    version=1, requiresSpecialistReview=False, **kwargs)

    def test_reviewed_ui_copy_can_publish(self):
        validate_translation(self.entry(), {'Continue'})

    def test_unreviewed_copy_cannot_publish(self):
        entry = self.entry(); entry['reviewed'] = False
        with self.assertRaisesRegex(ValueError, 'reviewed'):
            validate_translation(entry, {'Continue'})

    def test_sensitive_copy_cannot_downgrade_its_review_requirement(self):
        entry = self.entry(source='Your evidence stays private')
        with self.assertRaisesRegex(ValueError, 'Specialist'):
            validate_translation(entry, {entry['source']})
        entry['specialistReviewed'] = True
        validate_translation(entry, {entry['source']})

    def test_old_source_versions_are_rejected(self):
        entry = self.entry(); entry['version'] = 0
        with self.assertRaisesRegex(ValueError, 'version'):
            validate_translation(entry, {'Continue'})

    def test_empty_translation_is_rejected(self):
        entry = self.entry(); entry['translation'] = ' '
        with self.assertRaisesRegex(ValueError, 'Empty'):
            validate_translation(entry, {'Continue'})

if __name__ == '__main__': unittest.main()
