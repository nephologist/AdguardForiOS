import XCTest
import SQLite

class ProductionDatabaseManagerTest: XCTestCase {

    let rootDirectory = MetaStorageTestProcessor.rootDirectory
    let workingUrl = MetaStorageTestProcessor.workingUrl
    let fileManager = FileManager.default
    
    override class func setUp() {
        MetaStorageTestProcessor.deleteTestFolder()
        MetaStorageTestProcessor.clearRootDirectory()
    }
    
    override class func tearDown() {
        MetaStorageTestProcessor.deleteTestFolder()
        MetaStorageTestProcessor.clearRootDirectory()
    }
    
    override func tearDown() {
        MetaStorageTestProcessor.deleteTestFolder()
        MetaStorageTestProcessor.clearRootDirectory()
    }

    func testUpdateDatabaseSucceeded() {
        do {
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbFileRootUrl.path))
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileRootUrl.path))
            XCTAssertTrue(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbArchiveRootUrl.path))
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileWorkingUrl.path))
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbFileWorkingUrl.path))
            
            let productionDbManager = try ProductionDatabaseManager(dbContainerUrl: workingUrl)
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbFileRootUrl.path))
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileRootUrl.path))
            XCTAssertTrue(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbArchiveRootUrl.path))
            XCTAssertTrue(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileWorkingUrl.path))
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbFileWorkingUrl.path))
            
            try productionDbManager.updateDatabaseIfNeeded()
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbFileRootUrl.path))
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileRootUrl.path))
            XCTAssertTrue(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbArchiveRootUrl.path))
            XCTAssertTrue(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileWorkingUrl.path))
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbFileWorkingUrl.path))
            
            let versionTable = Table("version")
            let versionColumn = Expression<String>("schema_version")
            let filtersDb = try Connection(MetaStorageTestProcessor.adguardDbFileWorkingUrl.path)
            XCTAssertNotNil(try filtersDb.pluck(versionTable)?.get(versionColumn))
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testUpdateDatabaseWithNewVersionSucceeded() {
        do {
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbFileRootUrl.path))
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileRootUrl.path))
            XCTAssertTrue(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbArchiveRootUrl.path))
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileWorkingUrl.path))
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbFileWorkingUrl.path))
            
            try setUpOldVersionProductionDb()

            let productionDbManager = try ProductionDatabaseManager(dbContainerUrl: workingUrl)
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbFileRootUrl.path))
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileRootUrl.path))
            XCTAssertTrue(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbArchiveRootUrl.path))
            XCTAssertTrue(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileWorkingUrl.path))
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbFileWorkingUrl.path))
            
            try productionDbManager.updateDatabaseIfNeeded()
            
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbFileRootUrl.path))
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileRootUrl.path))
            XCTAssertTrue(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbArchiveRootUrl.path))
            XCTAssertTrue(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileWorkingUrl.path))
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbFileWorkingUrl.path))
            
            let versionTable = Table("version")
            let versionColumn = Expression<String>("schema_version")
            let filtersDb = try Connection(MetaStorageTestProcessor.adguardDbFileWorkingUrl.path)
            let version = try filtersDb.pluck(versionTable)?.get(versionColumn)
            XCTAssertTrue(try exists(column: "affinity", inTable: "filter_rules", forDB: filtersDb))
            XCTAssertTrue(try exists(column: "subscriptionUrl", inTable: "filters", forDB: filtersDb))
            XCTAssertNotNil(version)
            XCTAssertNotEqual(version, "0.100")
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testDBExistsAfterInitialization() {
        XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbFileRootUrl.path))
        XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileRootUrl.path))
        XCTAssertTrue(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbArchiveRootUrl.path))
        XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileWorkingUrl.path))
        XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbFileWorkingUrl.path))
        do {
            let _ = try ProductionDatabaseManager(dbContainerUrl: workingUrl)
            
            let pruductionDb = try Connection(MetaStorageTestProcessor.adguardDbFileWorkingUrl.path)
            XCTAssertTrue(try exists(column: "schema_version", inTable: "version", forDB: pruductionDb))
            
            let versionTable = Table("version")
            let versionColumn = Expression<String>("schema_version")
            let version = try pruductionDb.pluck(versionTable)?.get(versionColumn)
            XCTAssertNotNil(version)
            
            let filterTagsTable = Table("filter_tags")
            let filterTagsColumn = Expression<String>("name")
            let name = try pruductionDb.pluck(filterTagsTable)?.get(filterTagsColumn)
            XCTAssertNotNil(name)
            
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbFileRootUrl.path))
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileRootUrl.path))
            XCTAssertTrue(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbArchiveRootUrl.path))
            XCTAssertTrue(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileWorkingUrl.path))
            XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.defaultDbFileWorkingUrl.path))
            
        } catch {
            XCTFail("\(error)")
        }
    }
        
    //TODO: This method init empty adGuard.db. Add some SQL scripts to update data
    private func applySchemeToDefaultDb(db: Connection) throws {
        let dbSchemeFileFormat = "schema%@.sql" // %@ stands for schema version
        let version = "0.100" //old version
        let schemaFileName = String(format: dbSchemeFileFormat, version)
        let latestSchemaUrl = rootDirectory.appendingPathComponent(schemaFileName)
        let schemaQuery = try String(contentsOf: latestSchemaUrl)
        try db.execute(schemaQuery)
    }
    
    private func setUpOldVersionProductionDb() throws {
        
        try fileManager.createDirectory(at: workingUrl, withIntermediateDirectories: true, attributes: nil)
        
        XCTAssertFalse(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileWorkingUrl.path))
        let pruductionDb = try Connection(MetaStorageTestProcessor.adguardDbFileWorkingUrl.path)
        
        XCTAssertTrue(fileManager.fileExists(atPath: MetaStorageTestProcessor.adguardDbFileWorkingUrl.path))
        try applySchemeToDefaultDb(db: pruductionDb)

        
        let versionTable = Table("version")
        let versionColumn = Expression<String>("schema_version")
        let productionVersion = try pruductionDb.pluck(versionTable)?.get(versionColumn)

        XCTAssertEqual(productionVersion, "0.100")
        XCTAssertFalse(try exists(column: "affinity", inTable: "filter_rules", forDB: pruductionDb))
    }
    
    private func exists(column: String, inTable table: String, forDB db: Connection) throws -> Bool {
        let statement = try db.prepare("PRAGMA table_info(\(table))")
        
        let columnNames = statement.makeIterator().map { (row) -> String in
            return row[1] as? String ?? ""
        }
        
        return columnNames.contains(where: { dbColumn -> Bool in
            return dbColumn.caseInsensitiveCompare(column) == .orderedSame
        })
    }
}
