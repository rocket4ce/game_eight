defmodule GameEightWeb.PageController do
  use GameEightWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def test(conn, _params) do
    # Simple drag and drop test page
    html(conn, """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Drag and Drop Test</title>
        <style>
            .card {
                width: 60px;
                height: 80px;
                background: white;
                border: 2px solid #333;
                border-radius: 8px;
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                margin: 5px;
                cursor: grab;
                user-select: none;
            }
            .card.dragging {
                opacity: 0.5;
                transform: rotate(5deg);
            }
            .hand {
                display: flex;
                gap: 5px;
                padding: 20px;
                background: #e0f4e0;
                border-radius: 8px;
                min-height: 100px;
                align-items: center;
            }
            .drop-zone {
                width: 20px;
                height: 80px;
                border: 2px dashed transparent;
                transition: all 0.3s;
            }
            .drop-zone.drag-over {
                border-color: #007bff;
                background: rgba(0, 123, 255, 0.1);
            }
        </style>
    </head>
    <body>
        <h1>Drag and Drop Test</h1>
        <div class="hand" id="hand">
            <div class="drop-zone" data-position="0"></div>
            <div class="card" draggable="true" data-position="0">
                <div>4</div>
                <div>♥</div>
            </div>
            <div class="drop-zone" data-position="1"></div>
            <div class="card" draggable="true" data-position="1">
                <div>A</div>
                <div>♠</div>
            </div>
            <div class="drop-zone" data-position="2"></div>
            <div class="card" draggable="true" data-position="2">
                <div>K</div>
                <div>♦</div>
            </div>
            <div class="drop-zone" data-position="3"></div>
        </div>
        <script>
            document.addEventListener('DOMContentLoaded', function() {
                const cards = document.querySelectorAll('.card');
                const dropZones = document.querySelectorAll('.drop-zone');
                
                cards.forEach(card => {
                    card.addEventListener('dragstart', function(e) {
                        console.log('Drag started for card at position:', this.dataset.position);
                        e.dataTransfer.setData('text/plain', this.dataset.position);
                        this.classList.add('dragging');
                    });
                    
                    card.addEventListener('dragend', function(e) {
                        console.log('Drag ended for card at position:', this.dataset.position);
                        this.classList.remove('dragging');
                    });
                });
                
                dropZones.forEach(zone => {
                    zone.addEventListener('dragover', function(e) {
                        e.preventDefault();
                        this.classList.add('drag-over');
                    });
                    
                    zone.addEventListener('dragleave', function(e) {
                        this.classList.remove('drag-over');
                    });
                    
                    zone.addEventListener('drop', function(e) {
                        e.preventDefault();
                        const fromPosition = e.dataTransfer.getData('text/plain');
                        const toPosition = this.dataset.position;
                        console.log('Card dropped: from', fromPosition, 'to', toPosition);
                        this.classList.remove('drag-over');
                        
                        // Simple reorder demonstration
                        alert('Card would move from position ' + fromPosition + ' to position ' + toPosition);
                    });
                });
            });
        </script>
    </body>
    </html>
    """)
  end
end
