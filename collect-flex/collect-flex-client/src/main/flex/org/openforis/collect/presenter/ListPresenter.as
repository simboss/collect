package org.openforis.collect.presenter {
	/**
	 * 
	 * @author S. Ricci
	 * */
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.events.MouseEvent;
	
	import mx.collections.ArrayList;
	import mx.collections.IList;
	import mx.collections.ListCollectionView;
	import mx.controls.List;
	import mx.core.ClassFactory;
	import mx.core.FlexGlobals;
	import mx.events.StateChangeEvent;
	import mx.managers.PopUpManager;
	import mx.rpc.AsyncResponder;
	import mx.rpc.events.ResultEvent;
	
	import org.openforis.collect.Application;
	import org.openforis.collect.client.ClientFactory;
	import org.openforis.collect.client.DataClient;
	import org.openforis.collect.event.UIEvent;
	import org.openforis.collect.i18n.Message;
	import org.openforis.collect.metamodel.proxy.AttributeDefinitionProxy;
	import org.openforis.collect.metamodel.proxy.EntityDefinitionProxy;
	import org.openforis.collect.metamodel.proxy.NodeDefinitionProxy;
	import org.openforis.collect.metamodel.proxy.NodeLabelProxy;
	import org.openforis.collect.ui.UIBuilder;
	import org.openforis.collect.ui.component.AddNewRecordPopUp;
	import org.openforis.collect.ui.component.datagrid.PaginationBar;
	import org.openforis.collect.ui.component.datagrid.SelectRecordColumnHeaderRenderer;
	import org.openforis.collect.ui.component.datagrid.SelectRecordColumnItemRenderer;
	import org.openforis.collect.ui.view.ListView;
	
	import spark.collections.SortField;
	import spark.components.gridClasses.GridColumn;
	import spark.events.GridSortEvent;
	import spark.formatters.DateTimeFormatter;


	public class ListPresenter extends AbstractPresenter {
		
		private var _view:ListView;
		private var _dataClient:DataClient;
		
		private var _newRecordPopUp:AddNewRecordPopUp;
		
		/**
		 * The total number of records.
		 */
		private var totalRecords:int;
		/**
		 * The total pages of the pagination.
		 */
		private var totalPages:int;
		/**
		 * the current page of the pagination.
		 * It starts from 1 
		 */
		private var currentPage:int;
		/**
		 * the current orderBy column dataField
		 */
		private var currentOrderByFieldName:String;
		
		/**
		 * Max number of records that can be loaded for a single page.
		 */
		private const MAX_RECORDS_PER_PAGE:int = 20;
		
		public function ListPresenter(view:ListView) {
			this._view = view;
			this._dataClient = ClientFactory.dataClient;
			this._view.dataGrid.requestedRowCount = MAX_RECORDS_PER_PAGE;
			
			super();
		}

		override internal function initEventListeners():void {
			eventDispatcher.addEventListener(UIEvent.LOAD_RECORD_SUMMARIES, loadRecordSummariesHandler);

			this._view.newRecordButton.addEventListener(MouseEvent.CLICK, newRecordButtonClickHandler);
			
			this._view.dataGrid.addEventListener(GridSortEvent.SORT_CHANGING, dataGridSortChangingHandler);
			
			this._view.paginationBar.firstPageButton.addEventListener(MouseEvent.CLICK, firstPageClickHandler);
			this._view.paginationBar.previousPageButton.addEventListener(MouseEvent.CLICK, previousPageClickHandler);
			this._view.paginationBar.nextPageButton.addEventListener(MouseEvent.CLICK, nextPageClickHandler);
			this._view.paginationBar.lastPageButton.addEventListener(MouseEvent.CLICK, lastPageClickHandler);
			//this._view.paginationBar.goToPageButton.addEventListener(MouseEvent.CLICK, goToPageClickHandler);

		}
	
		/**
		 * New Record Button clicked 
		 * */
		protected function newRecordButtonClickHandler(event:MouseEvent):void {
			if(_newRecordPopUp == null) {
				_newRecordPopUp = new AddNewRecordPopUp();
				
			}
			PopUpManager.addPopUp(_newRecordPopUp, FlexGlobals.topLevelApplication as DisplayObject, true);
			PopUpManager.centerPopUp(_newRecordPopUp);
		}
		
		/**
		 * Loads records summaries for active root entity
		 * */
		protected function loadRecordSummariesHandler(event:UIEvent):void {
			updateDataGrid();
			currentPage = 1;
			loadRecordSummariesCurrentPage();
		}
		
		protected function updateDataGrid():void {
			var rootEntity:EntityDefinitionProxy = Application.activeRootEntity;
			var columns:IList = UIBuilder.getRecordSummaryListColumns(rootEntity);
			_view.dataGrid.columns = columns;
		}
		
		protected function loadRecordSummariesCurrentPage():void {
			_view.paginationBar.currentPageText.text = new String(currentPage);
			_view.paginationBar.currentState = PaginationBar.LOADING_STATE;
			
			//offset starts from 0
			var offset:int = (currentPage - 1) * MAX_RECORDS_PER_PAGE;
			
			_dataClient.getRecordSummaries(new AsyncResponder(getRecordsSummaryResultHandler, faultHandler), Application.activeRootEntity.name, 
				offset, MAX_RECORDS_PER_PAGE, currentOrderByFieldName);
		}
		
		protected function getRecordsSummaryResultHandler(event:ResultEvent, token:Object = null):void {
			var result:Object = event.result;
			var records:ListCollectionView = result.records;
			totalRecords = result.count as int;
			totalPages = Math.ceil(totalRecords / MAX_RECORDS_PER_PAGE);
			
			_view.dataGrid.dataProvider = records;

			updatePaginationBar();
		}
		
		protected function updatePaginationBar():void {
			var recordsFromPosition:int = ((currentPage - 1) * MAX_RECORDS_PER_PAGE) + 1;
			var recordsToPosition:int = recordsFromPosition + _view.dataGrid.dataProvider.length - 1;
			
			//calculate pagination bar state
			if(totalRecords == 0) {
				//no records found
				_view.paginationBar.currentState = PaginationBar.NO_PAGES_STATE;
			} else if(totalPages == 1) {
				//showing a single page
				_view.paginationBar.currentState = PaginationBar.SINGLE_PAGE_STATE;
			} else if(currentPage == 1) {
				//showing first page
				_view.paginationBar.currentState = PaginationBar.FIRST_PAGE_STATE;
			} else if(currentPage == totalPages) {
				//showing last page
				_view.paginationBar.currentState = PaginationBar.LAST_PAGE_STATE;
			} else {
				//showing a page in the middle
				_view.paginationBar.currentState = PaginationBar.MIDDLE_PAGE_STATE;
			}
		}
		
		/**
		 * Pagination bar events
		 * */
		protected function firstPageClickHandler(event:Event):void {
			currentPage = 1;
			loadRecordSummariesCurrentPage();
		}
		
		protected function previousPageClickHandler(event:Event):void {
			if(currentPage > 1) {
				currentPage --;
				loadRecordSummariesCurrentPage();
			}
		}
		
		protected function nextPageClickHandler(event:Event):void {
			if(currentPage < totalPages) {
				currentPage ++;
				loadRecordSummariesCurrentPage();
			}
		}
		
		protected function lastPageClickHandler(event:Event):void {
			currentPage = totalPages;
			loadRecordSummariesCurrentPage();
		}
		
		protected function goToPageClickHandler(event:Event):void {
			//currentPage = _view.paginationBar.goToPageStepper.value;
			loadRecordSummariesCurrentPage();
		}
		
		protected function dataGridSortChangingHandler(event:GridSortEvent):void {
			//avoid client sorting, perform the sorting by server side
			event.preventDefault();
			var newSortFields:Array = event.newSortFields;
			var sortField:SortField = newSortFields[0];
			currentOrderByFieldName = sortField.name;
			loadRecordSummariesCurrentPage();
		}
	}
}