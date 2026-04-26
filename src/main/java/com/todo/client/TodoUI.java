package com.todo.client;

import com.todo.model.Todo;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.type.TypeReference;
import javafx.application.Application;
import javafx.application.Platform;
import javafx.geometry.Insets;
import javafx.scene.Scene;
import javafx.scene.control.*;
import javafx.scene.layout.HBox;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;

public class TodoUI extends Application {

    private static final String API_URL = "http://127.0.0.1:8080/todos";
    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();
    private final ObjectMapper mapper = new ObjectMapper();
            
    private ListView<Todo> listView;

    public static void main(String[] args) {
        launch(args);
    }

    @Override
    public void start(Stage primaryStage) {
        primaryStage.setTitle("Todo App (JavaFX Client)");

        VBox root = new VBox(10);
        root.setPadding(new Insets(15));

        HBox inputLayout = new HBox(10);
        TextField inputField = new TextField();
        inputField.setPromptText("Add a new task...");
        Button addButton = new Button("Add");
        
        inputLayout.getChildren().addAll(inputField, addButton);

        listView = new ListView<>();
        
        // Custom cell factory
        listView.setCellFactory(param -> new ListCell<Todo>() {
            @Override
            protected void updateItem(Todo item, boolean empty) {
                super.updateItem(item, empty);
                if (empty || item == null) {
                    setText(null);
                    setGraphic(null);
                } else {
                    HBox pane = new HBox(10);
                    CheckBox checkBox = new CheckBox(item.getTitle());
                    checkBox.setSelected(item.isCompleted());
                    
                    checkBox.setOnAction(e -> toggleTodoContent(item.getId()));
                    
                    Button deleteButton = new Button("Delete");
                    deleteButton.setOnAction(e -> deleteTodoContent(item.getId()));
                    
                    pane.getChildren().addAll(checkBox, deleteButton);
                    setGraphic(pane);
                }
            }
        });

        root.getChildren().addAll(inputLayout, listView);

        addButton.setOnAction(e -> {
            String text = inputField.getText();
            if (!text.isEmpty()) {
                createTodoContent(text);
                inputField.clear();
            }
        });

        Scene scene = new Scene(root, 400, 500);
        primaryStage.setScene(scene);
        primaryStage.show();

        refreshTodos();
    }

    private void refreshTodos() {
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(API_URL))
                .GET()
                .build();

        httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                .thenApply(HttpResponse::body)
                .thenAccept(body -> {
                    try {
                        List<Todo> items = mapper.readValue(body, new TypeReference<List<Todo>>() {});
                        Platform.runLater(() -> {
                            listView.getItems().clear();
                            listView.getItems().addAll(items);
                        });
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                })
                .exceptionally(ex -> {
                    ex.printStackTrace();
                    return null;
                });
    }

    private void createTodoContent(String title) {
        try {
            Todo newTodo = new Todo();
            newTodo.setTitle(title);
            newTodo.setCompleted(false);
            String json = mapper.writeValueAsString(newTodo);
            
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(API_URL))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(json))
                    .build();

            httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                    .thenAccept(res -> refreshTodos());
        } catch(Exception e) {
            e.printStackTrace();
        }
    }

    private void toggleTodoContent(long id) {
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(API_URL + "/" + id))
                .method("PATCH", HttpRequest.BodyPublishers.noBody())
                .build();

        httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                .thenAccept(res -> refreshTodos());
    }

    private void deleteTodoContent(long id) {
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(API_URL + "/" + id))
                .DELETE()
                .build();

        httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                .thenAccept(res -> refreshTodos());
    }
}
