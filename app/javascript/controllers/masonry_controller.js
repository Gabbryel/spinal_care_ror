import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    function resizeGridItem(item){
      let grid = document.getElementsByClassName("grid-masonry")[0];
      grid.style.setProperty('row-gap', `${Number(5) + window.innerHeight / 100 }px`);
      grid.style.setProperty('column-gap', `3rem`);
      let rowHeight = parseInt(window.getComputedStyle(grid).getPropertyValue('grid-auto-rows'));
      let rowGap = parseInt(window.getComputedStyle(grid).getPropertyValue('grid-row-gap'));
      let rowSpan = Math.ceil((item.querySelector('.specialty-content').getBoundingClientRect().height+rowGap)/(rowHeight+rowGap));
      item.style.gridRowEnd = "span " + rowSpan;
    }
    function resizeAllGridItems(){
      let allItems = document.getElementsByClassName("medical-services-list__specialty");
      for(let x=0; x<allItems.length; x++){
         resizeGridItem(allItems[x]);
      }
   }
   window.onload = resizeAllGridItems()
   window.onresize = resizeAllGridItems()
  }
}