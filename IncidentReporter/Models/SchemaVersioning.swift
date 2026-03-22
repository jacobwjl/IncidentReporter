import SwiftData

// MARK: - Schema V1 (Initial Release)

enum IncidentReporterSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Incident.self,
            IncidentField.self,
            Report.self,
            ReportSection.self,
            FileAttachment.self,
            Tag.self,
            Contact.self,
            Deadline.self,
            ActivityLogEntry.self,
            ReportTemplate.self
        ]
    }
}

// MARK: - Migration Plan

enum IncidentReporterMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [IncidentReporterSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // Future migrations go here, e.g.:
        // .lightweight(fromVersion: IncidentReporterSchemaV1.self, toVersion: IncidentReporterSchemaV2.self)
        []
    }
}
