package com.internal.tasktracker;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@CrossOrigin(origins = "http://localhost:5173")
public class TaskController {

    private static final int MAX_PAGE_SIZE = 100;

    private final TaskRepository taskRepository;

    public TaskController(TaskRepository taskRepository) {
        this.taskRepository = taskRepository;
    }

    @GetMapping("/api/tasks")
    public ResponseEntity<?> searchTasks(
            @RequestParam(required = false, defaultValue = "") String q,
            @RequestParam(required = false) String status,
            @RequestParam(required = false, defaultValue = "1") int page,
            @RequestParam(required = false, defaultValue = "10") int pageSize) {

        // Validate pagination inputs up front.
        if (page < 1 || pageSize < 1) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "page and pageSize must be >= 1"));
        }
        pageSize = Math.min(pageSize, MAX_PAGE_SIZE);

        // Normalize query input.
        String query = q == null ? "" : q.trim();

        // Escape SQL LIKE wildcards so user input can't act as a wildcard.
        String escaped = query.toLowerCase()
                .replace("\\", "\\\\")
                .replace("%", "\\%")
                .replace("_", "\\_");
        String searchTerm = "%" + escaped + "%";

        // Parse status filter safely.
        String normalizedStatus = null;
        if (status != null && !status.isBlank()) {
            try {
                normalizedStatus = TaskStatus.valueOf(status.trim().toUpperCase()).name();
            } catch (IllegalArgumentException e) {
                return ResponseEntity.badRequest()
                        .body(Map.of("error", "Invalid status: " + status));
            }
        }

        List<Task> allResults = taskRepository.searchTasks(searchTerm, normalizedStatus);

        // Safe pagination math.
        long startL = (long) (page - 1) * pageSize;
        int start = (int) Math.min(startL, allResults.size());
        int end = (int) Math.min((long) start + pageSize, allResults.size());
        List<Task> pageResults = allResults.subList(start, end);

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("items", pageResults);
        response.put("total", allResults.size());
        response.put("page", page);
        response.put("pageSize", pageSize);

        return ResponseEntity.ok(response);
    }
}