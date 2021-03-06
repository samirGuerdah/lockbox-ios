/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Quick
import Nimble
import RxSwift
import RxCocoa
import RxDataSources

@testable import Lockbox

class ItemDetailViewSpec: QuickSpec {

    class FakeItemDetailPresenter: ItemDetailPresenter {
        var onViewReadyCalled = false
        var onPasswordToggleActionDispatched: Bool?
        var onCancelActionDispatched = false
        var onCellTappedValue: String?

        override func onViewReady() {
            self.onViewReadyCalled = true
        }

        override var onPasswordToggle: AnyObserver<Bool> {
            return Binder(self) { target, argument in
                target.onPasswordToggleActionDispatched = argument
            }.asObserver()
        }

        override var onCancel: AnyObserver<Void> {
            return Binder(self) { target, _ in
                target.onCancelActionDispatched = true
            }.asObserver()
        }

        override var onCellTapped: AnyObserver<String?> {
            return Binder(self) { target, value in
                target.onCellTappedValue = value
            }.asObserver()
        }
    }

    private var presenter: FakeItemDetailPresenter!
    var subject: ItemDetailView!

    override func spec() {
        describe("ItemDetailView") {
            beforeEach {
                let sb = UIStoryboard(name: "ItemDetail", bundle: nil)
                self.subject = sb.instantiateViewController(withIdentifier: "itemdetailview") as! ItemDetailView
                self.presenter = FakeItemDetailPresenter(view: self.subject)

                self.subject.presenter = self.presenter

                self.subject.preloadView()
            }

            it("informs the presenter") {
                expect(self.presenter.onViewReadyCalled).to(beTrue())
            }

            describe("itemId") {
                it("returns an empty string when it hasn't been configured") {
                    expect(self.subject.itemId).to(equal(""))
                }

                it("returns the itemId it was configured with") {
                    let id = "fdssdfdfsdf"
                    self.subject.itemId = id
                    expect(self.subject.itemId).to(equal(id))
                }
            }

            describe("tableview datasource configuration") {
                let configDriver = PublishSubject<[ItemDetailSectionModel]>()
                let sectionModels = [
                    ItemDetailSectionModel(model: 0, items: [
                        ItemDetailCellConfiguration(
                                title: Constant.string.webAddress,
                                value: "www.meow.com",
                                password: false)
                    ]),
                    ItemDetailSectionModel(model: 1, items: [
                        ItemDetailCellConfiguration(
                                title: Constant.string.username,
                                value: "tanya",
                                password: false),
                        ItemDetailCellConfiguration(
                                title: Constant.string.password,
                                value: "••••••••••",
                                password: true)
                    ]),
                    ItemDetailSectionModel(model: 2, items: [
                        ItemDetailCellConfiguration(
                                title: Constant.string.notes,
                                value: "some long note about whatever thing yeahh",
                                password: false)
                    ])
                ]

                beforeEach {
                    self.subject.bind(itemDetail: configDriver.asDriver(onErrorJustReturn: []))

                    configDriver.onNext(sectionModels)
                }

                it("configures the tableview based on the models provided") {
                    expect(self.subject.tableView.numberOfSections).to(equal(sectionModels.count))
                }

                it("binds password reveal tap actions to the appropriate presenter listener") {
                    let cell = self.subject.tableView.cellForRow(at: [1, 1]) as! ItemDetailCell
                    cell.revealButton.sendActions(for: .touchUpInside)

                    expect(self.presenter.onPasswordToggleActionDispatched).to(beTrue())
                }

                describe("tapping cells") {
                    beforeEach {
                        self.subject.tableView.delegate!.tableView!(self.subject.tableView, didSelectRowAt: [1, 0])
                    }

                    it("extracts the titlelabel text and tells the presenter") {
                        expect(self.presenter.onCellTappedValue).to(equal(Constant.string.username))
                    }
                }
            }

            describe("title text") {
                let textDriver = PublishSubject<String>()
                beforeEach {
                    self.subject.bind(titleText: textDriver.asDriver(onErrorJustReturn: ""))
                }

                it("updates the navigation title with new values") {
                    let title = "new title"
                    textDriver.onNext(title)
                    expect(self.subject.navigationItem.title).to(equal(title))
                }
            }

            describe("tapping cancel button") {
                beforeEach {
                    let button = self.subject.navigationItem.leftBarButtonItem!.customView as! UIButton
                    _ = button.sendActions(for: .touchUpInside)
                }

                it("informs the presenter") {
                    expect(self.presenter.onCancelActionDispatched).to(beTrue())
                }
            }

            describe("tapping a password reveal button") {
                let sectionModelWithJustPassword = [
                    ItemDetailSectionModel(model: 1, items: [
                        ItemDetailCellConfiguration(
                                title: Constant.string.password,
                                value: "••••••••••",
                                password: true)
                    ])
                ]

                beforeEach {
                    self.subject.bind(itemDetail: Driver.just(sectionModelWithJustPassword))
                }

                it("returns the selected state of the password reveal button") {
                    let cell = self.subject.tableView.cellForRow(at: [0, 0]) as! ItemDetailCell
                    cell.revealButton.sendActions(for: .touchUpInside)

                    expect(self.presenter.onPasswordToggleActionDispatched).notTo(beNil())
                    expect(self.presenter.onPasswordToggleActionDispatched).to(equal(cell.revealButton.isSelected))
                }
            }

            describe("ItemDetailCell") {
                let sectionModelWithJustPassword = [
                    ItemDetailSectionModel(model: 1, items: [
                        ItemDetailCellConfiguration(
                                title: Constant.string.password,
                                value: "••••••••••",
                                password: true)
                    ])
                ]

                beforeEach {
                    self.subject.bind(itemDetail: Driver.just(sectionModelWithJustPassword))
                }

                it("prepareForReuse disposes the cell's dispose bag") {
                    let cell = self.subject.tableView.cellForRow(at: [0, 0]) as! ItemDetailCell

                    let disposeBag = cell.disposeBag

                    cell.prepareForReuse()

                    expect(cell.disposeBag === disposeBag).notTo(beTrue())
                }
            }

            describe("ItemDetailCell") {
                let sectionModel = [
                    ItemDetailSectionModel(model: 1, items: [
                        ItemDetailCellConfiguration(
                                title: Constant.string.password,
                                value: "••••••••••",
                                password: true)
                    ])
                ]

                beforeEach {
                    self.subject.bind(itemDetail: Driver.just(sectionModel))
                }

                it("highlighting the cell changes the background color") {
                    let cell = self.subject.tableView.cellForRow(at: [0, 0]) as! ItemDetailCell

                    cell.setHighlighted(true, animated: false)
                    expect(cell.backgroundColor).to(equal(Constant.color.tableViewCellHighlighted))

                    cell.setHighlighted(false, animated: false)
                    expect(cell.backgroundColor).to(equal(UIColor.white))
                }
            }
        }

        describe("ItemDetailViewCellConfiguration") {
            describe("IdentifiableType") {
                let title = "meow"
                let cellConfig = ItemDetailCellConfiguration(title: title, value: "cats", password: false)

                it("uses the title as the identity string") {
                    expect(cellConfig.identity).to(equal(title))
                }
            }

            describe("equality") {
                it("uses the value to determine equality") {
                    expect(ItemDetailCellConfiguration(
                            title: "meow",
                            value: "cats",
                            password: false)
                    ).to(equal(ItemDetailCellConfiguration(
                            title: "meow",
                            value: "cats",
                            password: false)
                    ))

                    expect(ItemDetailCellConfiguration(
                            title: "woof",
                            value: "cats",
                            password: false)
                    ).to(equal(ItemDetailCellConfiguration(
                            title: "meow",
                            value: "cats",
                            password: false)
                    ))

                    expect(ItemDetailCellConfiguration(
                            title: "meow",
                            value: "dogs",
                            password: false)
                    ).notTo(equal(ItemDetailCellConfiguration(
                            title: "meow",
                            value: "cats",
                            password: false)
                    ))
                }
            }
        }
    }
}
