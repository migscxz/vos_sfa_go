# Order Form Cleanup and Online-First Implementation

## Completed Tasks ✅

- [x] Remove embedded SupplierSearchDialog class and use existing SupplierPickerModal
- [x] Remove embedded CustomerSearchDialog class and use existing CustomerPickerModal
- [x] Remove embedded MultiSelectProductDialog class and use existing ProductMultiPickerModal
- [x] Update method calls to use proper modal widgets
- [x] Add necessary imports for modal widgets

## Next Steps for Online-First Implementation

- [ ] Modify data loading methods to prioritize API calls over local database
- [ ] Simplify \_loadMasterData() to focus on API-first approach
- [ ] Remove complex local DB seeding and fallback logic
- [ ] Update customer loading to use API endpoints
- [ ] Update supplier loading to use API endpoints
- [ ] Update product loading to use API endpoints
- [ ] Implement proper error handling for API failures
- [ ] Add loading states for API calls
- [ ] Test the online-first form functionality

## Future: Offline-First Implementation

- [ ] Implement offline data caching
- [ ] Add sync mechanisms for offline/online transitions
- [ ] Handle network connectivity changes
- [ ] Implement conflict resolution for offline edits
