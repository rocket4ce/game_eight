/**
 * Phoenix LiveView Hooks for Card Drag and Drop
 *
 * Provides functionality for:
 * 1. Hand card reordering - drag cards within player's hand
 * 2. Table card taking - drag cards from table combinations to hand
 * 3. Visual feedback for valid/invalid drops
 * 4. Touch support for mobile devices
 */

// Hook for making cards draggable
export const CardDragSource = {
  mounted() {
    console.log('CardDragSource mounted for element:', this.el.id)
    this.setupDragging()
    this.setupTouchEvents()
  },

  updated() {
    console.log('CardDragSource updated for element:', this.el.id)
    this.setupDragging()
    this.setupTouchEvents()
  },

  setupDragging() {
    this.el.draggable = true
    this.el.style.cursor = 'grab'

    this.el.addEventListener('dragstart', (e) => {
      console.log('Drag started for card:', this.el.dataset.position)

      const cardData = {
        position: this.el.dataset.position,
        source: this.el.dataset.source, // 'hand' or 'table'
        combinationName: this.el.dataset.combinationName || null,
        cardValue: this.el.dataset.cardValue,
        cardType: this.el.dataset.cardType,
        deck: this.el.dataset.deck || null
      }

      e.dataTransfer.setData('application/json', JSON.stringify(cardData))
      e.dataTransfer.effectAllowed = 'move'

      // Add visual feedback
      this.el.classList.add('dragging')
      this.el.style.cursor = 'grabbing'

      // Store reference for cleanup
      this.draggedElement = this.el

      // Add visual hints to valid drop zones
      this.highlightValidDropZones(cardData)
    })

    this.el.addEventListener('dragend', (e) => {
      console.log('Drag ended for card:', this.el.dataset.position)
      this.el.classList.remove('dragging')
      this.el.style.cursor = 'grab'
      this.draggedElement = null

      // Clean up visual hints
      this.clearDropZoneHighlights()
    })
  },

  highlightValidDropZones(cardData) {
    const dropZones = document.querySelectorAll('[data-drop-zone]')
    dropZones.forEach(zone => {
      if (this.isValidDropForZone(zone, cardData)) {
        zone.classList.add('valid-drop-hint')
      } else {
        zone.classList.add('invalid-drop-hint')
      }
    })
  },

  clearDropZoneHighlights() {
    const dropZones = document.querySelectorAll('[data-drop-zone]')
    dropZones.forEach(zone => {
      zone.classList.remove('valid-drop-hint', 'invalid-drop-hint')
    })
  },

  isValidDropForZone(zone, cardData) {
    const dropZoneType = zone.dataset.dropZone
    console.log('Checking valid drop for zone:', { dropZoneType, cardData })

    if (dropZoneType === 'hand-reorder') {
      return cardData.source === 'hand'
    }

    if (dropZoneType === 'hand' && cardData.source === 'table') {
      // Check if it's current player's turn
      const turnIndicator = document.querySelector('.turn-indicator.active')
      if (!turnIndicator) return false

      // Check if removing this card would leave at least 3 cards
      const combinationElement = document.querySelector(`[data-combination-name="${cardData.combinationName}"]`)
      if (!combinationElement) return false

      const cardsInCombination = combinationElement.querySelectorAll('.game-card').length
      return cardsInCombination > 3
    }

    if (dropZoneType === 'add-to-combination' && cardData.source === 'hand') {
      console.log('Checking add-to-combination validation for hand card')
      // Check if it's current player's turn using data attribute
      const isCurrentTurn = zone.dataset.isCurrentTurn === 'true'
      console.log('isCurrentTurn value:', zone.dataset.isCurrentTurn, 'parsed as:', isCurrentTurn)
      if (!isCurrentTurn) {
        console.log('Not current player turn')
        return false
      }

      console.log('Current player turn confirmed, allowing drop')
      // Always allow adding cards from hand to existing combinations
      // Validation will be handled server-side
      return true
    }

    if (dropZoneType === 'add-to-combination' && cardData.source === 'table') {
      console.log('Checking move between combinations validation')
      // Check if it's current player's turn
      const isCurrentTurn = zone.dataset.isCurrentTurn === 'true'
      if (!isCurrentTurn) {
        console.log('Not current player turn')
        return false
      }

      // Check that source and target are different combinations
      const targetCombination = zone.dataset.combinationName
      if (cardData.combinationName === targetCombination) {
        console.log('Cannot move card to same combination')
        return false
      }

      // Check that source combination has more than 3 cards
      const combinationElement = document.querySelector(`[data-combination-name="${cardData.combinationName}"]`)
      if (!combinationElement) return false

      const cardsInCombination = combinationElement.querySelectorAll('.game-card').length
      if (cardsInCombination <= 3) {
        console.log('Cannot move card: would leave less than 3 cards in source')
        return false
      }

      console.log('Move between combinations validation passed')
      return true
    }

    console.log('No matching drop zone type, returning false')
    return false
  },

  setupTouchEvents() {
    let touchStartData = null

    this.el.addEventListener('touchstart', (e) => {
      e.preventDefault()
      const touch = e.touches[0]
      touchStartData = {
        startX: touch.clientX,
        startY: touch.clientY,
        element: this.el,
        timestamp: Date.now()
      }

      this.el.classList.add('touch-dragging')
    })

    this.el.addEventListener('touchmove', (e) => {
      if (!touchStartData) return
      e.preventDefault()

      const touch = e.touches[0]
      const deltaX = touch.clientX - touchStartData.startX
      const deltaY = touch.clientY - touchStartData.startY

      // Visual feedback for touch drag
      this.el.style.transform = `translate(${deltaX}px, ${deltaY}px)`
      this.el.style.zIndex = '1000'

      // Find drop target under finger
      const elementBelow = document.elementFromPoint(touch.clientX, touch.clientY)
      const dropZone = elementBelow?.closest('[data-drop-zone]')

      if (dropZone) {
        dropZone.classList.add('touch-drag-over')
        // Remove class from other drop zones
        document.querySelectorAll('[data-drop-zone]').forEach(zone => {
          if (zone !== dropZone) {
            zone.classList.remove('touch-drag-over')
          }
        })
      }
    })

    this.el.addEventListener('touchend', (e) => {
      if (!touchStartData) return
      e.preventDefault()

      const touch = e.changedTouches[0]
      const elementBelow = document.elementFromPoint(touch.clientX, touch.clientY)
      const dropZone = elementBelow?.closest('[data-drop-zone]')

      // Reset visual state
      this.el.style.transform = ''
      this.el.style.zIndex = ''
      this.el.classList.remove('touch-dragging')
      document.querySelectorAll('[data-drop-zone]').forEach(zone => {
        zone.classList.remove('touch-drag-over')
      })

      // Handle drop if valid drop zone
      if (dropZone) {
        const cardData = {
          position: this.el.dataset.position,
          source: this.el.dataset.source,
          combinationName: this.el.dataset.combinationName || null,
          cardValue: this.el.dataset.cardValue,
          cardType: this.el.dataset.cardType,
          deck: this.el.dataset.deck || null
        }

        const dropData = {
          target: dropZone.dataset.dropZone,
          targetPosition: dropZone.dataset.position || null,
          combinationName: dropZone.dataset.combinationName || null
        }

        this.handleDrop(cardData, dropData)
      }

      touchStartData = null
    })
  },

  handleDrop(cardData, dropData) {
    console.log('HandleDrop called with:', { cardData, dropData })

    // Send event to LiveView based on drop type
    if (dropData.target === 'hand-reorder') {
      console.log('Sending reorder_hand_card event')
      this.pushEvent('reorder_hand_card', {
        from_position: cardData.position,
        to_position: dropData.targetPosition
      })
    } else if (dropData.target === 'hand' && cardData.source === 'table') {
      console.log('Sending take_table_card event')
      this.pushEvent('take_table_card', {
        combination_name: cardData.combinationName,
        card_position: cardData.position
      })
    } else if (dropData.target === 'add-to-combination' && cardData.source === 'hand') {
      console.log('Sending add_cards_to_combination event with:', {
        combination_name: dropData.combinationName,
        card_positions: [cardData.position]
      })
      this.pushEvent('add_cards_to_combination', {
        combination_name: dropData.combinationName,
        card_positions: [cardData.position]
      })
    } else if (dropData.target === 'add-to-combination' && cardData.source === 'table') {
      console.log('Sending move_card_between_combinations event')
      this.pushEvent('move_card_between_combinations', {
        source_combination: cardData.combinationName,
        target_combination: dropData.combinationName,
        card_id: `${cardData.cardValue}_${cardData.cardType}_${cardData.deck}`
      })
    } else {
      console.log('No matching drop handler for:', { target: dropData.target, source: cardData.source })
    }
  }
}

// Hook for drop zones (hand area, specific positions)
export const CardDropZone = {
  mounted() {
    console.log('CardDropZone mounted for element:', this.el.id)
    this.setupDropZone()
  },

  updated() {
    console.log('CardDropZone updated for element:', this.el.id)
    this.setupDropZone()
  },

  setupDropZone() {
    console.log('Setting up drop zone:', this.el.id, 'type:', this.el.dataset.dropZone)

    this.el.addEventListener('dragover', (e) => {
      e.preventDefault()
      e.dataTransfer.dropEffect = 'move'

      const cardData = this.getCardDataFromTransfer(e.dataTransfer)
      if (this.isValidDrop(cardData)) {
        this.el.classList.add('valid-drop')
        this.el.classList.remove('invalid-drop')
      } else {
        this.el.classList.add('invalid-drop')
        this.el.classList.remove('valid-drop')
      }
    })

    this.el.addEventListener('dragleave', (e) => {
      this.el.classList.remove('valid-drop', 'invalid-drop')
    })

    this.el.addEventListener('drop', (e) => {
      e.preventDefault()
      console.log('Drop event triggered on:', this.el.id)
      this.el.classList.remove('valid-drop', 'invalid-drop')

      try {
        const cardData = JSON.parse(e.dataTransfer.getData('application/json'))
        console.log('Dropped card data:', cardData)

        const dropData = {
          target: this.el.dataset.dropZone,
          targetPosition: this.el.dataset.position || null,
          combinationName: this.el.dataset.combinationName || null
        }
        console.log('Drop data:', dropData)

        if (this.isValidDrop(cardData)) {
          this.handleDrop(cardData, dropData)
        } else {
          console.log('Invalid drop attempted')
        }
      } catch (error) {
        console.error('Error handling drop:', error)
      }
    })
  },

  getCardDataFromTransfer(dataTransfer) {
    try {
      // In dragover, we can't access the data, so we use the types
      const types = Array.from(dataTransfer.types)
      if (types.includes('application/json')) {
        return {} // Valid format, actual validation will happen on drop
      }
    } catch (error) {
      return null
    }
    return null
  },

  isValidDrop(cardData) {
    const dropZoneType = this.el.dataset.dropZone

    // For hand reordering: only allow hand cards to be dropped in hand
    if (dropZoneType === 'hand-reorder') {
      return cardData.source === 'hand'
    }

    // For taking table cards: only allow table cards to be dropped in hand (and only during current player's turn)
    if (dropZoneType === 'hand' && cardData.source === 'table') {
      // Check if it's the current player's turn
      const turnIndicator = document.querySelector('.turn-indicator.active')
      if (!turnIndicator) {
        return false
      }

      // Additional validation could be added here to check combination rules
      return this.validateTableCardTaking(cardData)
    }

    // For adding cards to combinations: only allow hand cards to be dropped in combinations
    if (dropZoneType === 'add-to-combination' && cardData.source === 'hand') {
      console.log('CardDropZone isValidDrop: checking add-to-combination for hand card')
      // Check if it's the current player's turn using data attribute
      const isCurrentTurn = this.el.dataset.isCurrentTurn === 'true'
      console.log('CardDropZone isCurrentTurn:', this.el.dataset.isCurrentTurn, 'parsed as:', isCurrentTurn)
      if (!isCurrentTurn) {
        console.log('CardDropZone: Not current turn, rejecting drop')
        return false
      }

      console.log('CardDropZone: Current turn confirmed, allowing drop')
      // Allow the drop - server will validate if the combination is valid
      return true
    }

    // For moving cards between combinations: only allow table cards to be dropped in different combinations
    if (dropZoneType === 'add-to-combination' && cardData.source === 'table') {
      console.log('CardDropZone isValidDrop: checking move between combinations')
      // Check if it's the current player's turn
      const isCurrentTurn = this.el.dataset.isCurrentTurn === 'true'
      if (!isCurrentTurn) {
        console.log('CardDropZone: Not current turn, rejecting move')
        return false
      }

      // Check that source and target combinations are different
      const targetCombination = this.el.dataset.combinationName
      if (cardData.combinationName === targetCombination) {
        console.log('CardDropZone: Cannot move card to same combination')
        return false
      }

      // Check that source combination has more than 3 cards
      const sourceCombinationElement = document.querySelector(`[data-combination-name="${cardData.combinationName}"]`)
      if (!sourceCombinationElement) return false

      const cardsInSource = sourceCombinationElement.querySelectorAll('.game-card').length
      if (cardsInSource <= 3) {
        console.log('CardDropZone: Cannot move card, source would have less than 3 cards')
        return false
      }

      console.log('CardDropZone: Move between combinations allowed')
      return true
    }

    return false
  },

  validateTableCardTaking(cardData) {
    // Find the combination this card belongs to
    const combinationElement = document.querySelector(`[data-combination-name="${cardData.combinationName}"]`)
    if (!combinationElement) return false

    // Count cards in the combination
    const cardsInCombination = combinationElement.querySelectorAll('.game-card').length

    // Must leave at least 3 cards in the combination
    if (cardsInCombination <= 3) {
      console.log(`Cannot take card: would leave only ${cardsInCombination - 1} cards in combination (minimum 3 required)`)
      return false
    }

    // Additional validation: check if it's the current player's turn
    const turnIndicator = document.querySelector('.turn-indicator.active')
    if (!turnIndicator) {
      console.log('Cannot take card: not your turn')
      return false
    }

    console.log(`Can take card: ${cardsInCombination - 1} cards will remain in combination`)
    return true
  },

  handleDrop(cardData, dropData) {
    // Use the CardDragSource's handleDrop method
    const dragSource = document.querySelector(`[data-position="${cardData.position}"]`)
    if (dragSource && dragSource.phxHook) {
      dragSource.phxHook.handleDrop(cardData, dropData)
    } else {
      // Fallback: send event directly
      if (dropData.target === 'hand-reorder') {
        this.pushEvent('reorder_hand_card', {
          from_position: cardData.position,
          to_position: dropData.targetPosition
        })
      } else if (dropData.target === 'hand' && cardData.source === 'table') {
        this.pushEvent('take_table_card', {
          combination_name: cardData.combinationName,
          card_position: cardData.position
        })
      } else if (dropData.target === 'add-to-combination' && cardData.source === 'hand') {
        this.pushEvent('add_cards_to_combination', {
          combination_name: dropData.combinationName,
          card_positions: [cardData.position]
        })
      }
    }
  }
}

// Utility functions for card validation
export const CardValidation = {
  // Check if removing a card from table combination would leave at least 3 cards
  canTakeFromCombination(combinationCards, cardToRemove) {
    const remainingCards = combinationCards.filter(card =>
      card.position !== cardToRemove.position
    )

    // Must have at least 3 cards remaining
    if (remainingCards.length < 3) {
      return false
    }

    // Check if remaining cards still form a valid combination
    return this.isValidTrio(remainingCards) || this.isValidSequence(remainingCards)
  },

  isValidTrio(cards) {
    if (cards.length < 3) return false

    // All cards must have the same value
    const firstCard = cards[0]
    return cards.every(card => card.card === firstCard.card)
  },

  isValidSequence(cards) {
    if (cards.length < 3) return false

    // All cards must be the same suit
    const firstCard = cards[0]
    if (!cards.every(card => card.type === firstCard.type)) {
      return false
    }

    // Sort cards by value and check if they're consecutive
    const values = cards.map(card => this.getCardValue(card.card)).sort((a, b) => a - b)

    for (let i = 1; i < values.length; i++) {
      if (values[i] !== values[i-1] + 1) {
        return false
      }
    }

    return true
  },

  getCardValue(cardStr) {
    const value = cardStr.toUpperCase()
    if (value === 'A') return 1
    if (value === 'J') return 11
    if (value === 'Q') return 12
    if (value === 'K') return 13
    return parseInt(value, 10)
  }
}
