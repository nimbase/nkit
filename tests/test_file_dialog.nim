import unittest
import nkit/file_dialog

suite "file dialogs (configuration)":
  test "open panel stores configuration":
    let dlg = newOpenFileDialog("Pick files")
    dlg.setAllowsMultiple(true)
    dlg.setCanChooseDirectories(true)
    dlg.setFilters(@["png", "jpg"])
    dlg.setInitialDirectory("/tmp")
    check dlg.titleValue == "Pick files"
    check dlg.allowsMultipleValue == true
    check dlg.canChooseDirectoriesValue == true
    check dlg.filtersValue == @["png", "jpg"]
    check dlg.initialDirectoryValue == "/tmp"

  test "open panel defaults":
    let dlg = newOpenFileDialog()
    check dlg.titleValue == ""
    check dlg.allowsMultipleValue == false
    check dlg.canChooseDirectoriesValue == false
    check dlg.filtersValue.len == 0

  test "save panel stores name and filters":
    let dlg = newSaveFileDialog("Export", "report.pdf")
    check dlg.titleValue == "Export"
    check dlg.defaultNameValue == "report.pdf"
    dlg.setNameField("invoice.pdf")
    check dlg.defaultNameValue == "invoice.pdf"
    dlg.setFilters(@["pdf"])
    check dlg.filtersValue == @["pdf"]
